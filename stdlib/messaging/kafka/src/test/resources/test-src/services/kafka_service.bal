// Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/kafka;
import ballerina/io;

string topic = "service-test";

kafka:ConsumerConfig consumerConfigs = {
    bootstrapServers: "localhost:9094",
    groupId: "service-test-group",
    clientId: "service-consumer",
    offsetReset: "earliest",
    topics: [topic]
};

listener kafka:Consumer kafkaConsumer = new(consumerConfigs);

int count = 0;

service kafkaTestService on kafkaConsumer {
    resource function onMessage(kafka:Consumer consumer, kafka:ConsumerRecord[] records) {
        count = 10;
    }
}

public function funcKafkaGetResult() returns int {
    return count;
}
