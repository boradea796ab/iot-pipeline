package com.iot;

import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

public class MinimalFlinkJob {
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env =
                StreamExecutionEnvironment.getExecutionEnvironment();

        env.fromElements("hello", "world").print();

        env.execute("Minimal IoT Flink Job");
    }
}
