package com.supply.risk.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;

/**
 * 线程池配置，批量评分计算线程池与 API 线程池物理隔离。
 */
@Configuration
@EnableAsync
public class ThreadPoolConfig {

    @Value("${scrm.scoring.executor.core-pool-size:8}")
    private int corePoolSize;

    @Value("${scrm.scoring.executor.max-pool-size:16}")
    private int maxPoolSize;

    @Value("${scrm.scoring.executor.queue-capacity:200}")
    private int queueCapacity;

    @Value("${scrm.scoring.executor.thread-name-prefix:scoring-worker-}")
    private String threadNamePrefix;

    @Value("${scrm.scoring.executor.keep-alive-seconds:60}")
    private int keepAliveSeconds;

    /**
     * 批量评分专用线程池（与 API 线程池隔离，防止计算任务抢占 API 请求资源）。
     *
     * @return 线程池执行器
     */
    @Bean("scoringExecutor")
    public Executor scoringExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(corePoolSize);
        executor.setMaxPoolSize(maxPoolSize);
        executor.setQueueCapacity(queueCapacity);
        executor.setThreadNamePrefix(threadNamePrefix);
        executor.setKeepAliveSeconds(keepAliveSeconds);
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }
}
