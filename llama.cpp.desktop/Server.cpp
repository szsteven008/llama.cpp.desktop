//
//  Server.cpp
//  llama.cpp.desktop
//
//  Created by steve.tang on 2026/4/28.
//

#include "Server.hpp"
#include <fstream>
#include <thread>
#include <future>
#include <boost/process.hpp>

static auto path_home = std::string(std::getenv("HOME"));
static auto path_model = path_home + "/.llama.cpp/models.ini";
static auto path_bin = path_home + "/.llama.cpp/bin/llama-server";

std::vector<std::string> models() {
    std::vector<std::string> m;
        
    std::ifstream f(path_model);
    if (f.is_open()) {
        for (std::string line; std::getline(f, line, '\n'); ) {
            if (line.starts_with("[") && line.ends_with("]")) {
                m.emplace_back(line.substr(1, line.size() - 2));
            }
        }
        
        f.close();
    }
    
    return m;
}

static std::mutex log_queue_mutex;
static std::condition_variable log_queue_conv;
static std::queue<std::string> log_queue;

void log_push(const std::string& buffer) {
    {
        const int max_log_message = 1000;
        std::lock_guard<std::mutex> l(log_queue_mutex);
        if (log_queue.size() > max_log_message) log_queue.pop();
        log_queue.emplace(buffer);
    }
    log_queue_conv.notify_all();
}

std::string log_get() {
    std::unique_lock<std::mutex> l(log_queue_mutex);
    if (!log_queue_conv.wait_for(
        l,
        std::chrono::milliseconds(100),
        [] { return !log_queue.empty(); }
    )) {
        return "";
    }
    std::string message = log_queue.front();
    log_queue.pop();
    
    return message;
}

static std::unique_ptr<std::jthread> handle_thread;
void start() {
    handle_thread.reset(new std::jthread(
        [](std::stop_token stoken) {
            boost::asio::io_context ctx;
            boost::asio::readable_pipe rp { ctx };
            boost::process::process proc {
                ctx,
                path_bin.c_str(),
                { "--models-preset", path_model, "--models-max", "1" },
                boost::process::process_stdio({ nullptr, {}, rp })
            };
            
            std::string overflow = "";
            auto parse_line = [&](const std::string buffer) {
                auto n = buffer.find_last_of("\n");
                if (n == std::string::npos) {
                    overflow = overflow + buffer;
                    return;
                }
                
                std::string s = overflow + buffer.substr(0, n);
                std::istringstream iss(s);
                overflow = buffer.substr(n);
                
                for (std::string line; std::getline(iss, line, '\n'); ) {
                    if (line.size() > 0) {
                        //std::cout << line << std::endl;
                        //std::cout.flush();
                        log_push(line);
                    }
                }
            };
            
            std::vector<char> buffer(1024);
            std::function<void()> do_read = [&] {
                rp.async_read_some(
                    boost::asio::buffer(buffer),
                    [&](const boost::system::error_code ec, std::size_t length) {
                        if (!ec) {
                            parse_line(std::string(buffer.data(), length));
                            do_read();
                        }
                        return;
                    }
                );
            };
            do_read();
                                         
            auto c_future = std::async(
                std::launch::async,
                [&] {
                    ctx.run();
                });
            while (!stoken.stop_requested() && proc.running()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }
            
            {
                boost::system::error_code ec;
                rp.close(ec);
            }
            ctx.stop();
            c_future.wait();
            
            if (proc.running()) {
                proc.interrupt();
                proc.wait();
            }
        }
    ));
}

void stop() {
    if (handle_thread && handle_thread->joinable()) {
        handle_thread->request_stop();
        handle_thread->join();
        handle_thread.release();
    }
}
