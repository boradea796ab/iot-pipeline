# Smart Meter IoT Architecture

This diagram reflects the resources currently defined in `terraform/*.tf`.

```mermaid
flowchart LR
  %% External producers/consumers
  SIM[IoT Simulator]
  USER[Grafana Admins\n(AWS SSO Role ARNs)]

  %% AWS account boundary
  subgraph AWS[AWS Account]
    IOT[AWS IoT Core\nThing + Cert + Policy]
    RULE[IoT Topic Rule\nmeters/+/readings]
    KDS[Kinesis Data Stream\nsmart-meter-iot-telemetry]

    subgraph VPC[VPC 10.0.0.0/16]
      subgraph PRIV[Private Subnets]
        LAMBDA[AWS Lambda\nkinesis-to-influx]
        INFLUX[Timestream for InfluxDB\nsmart-meter-iot-influxdb]
      end
      RT[Private Route Table]
      S3EP[S3 Gateway Endpoint]
      SG1[Lambda Security Group]
      SG2[InfluxDB Security Group]
    end

    SSM[SSM Parameter Store\ninfluxdb write URL + token]
    CW[Amazon CloudWatch]
    GRAFANA[Amazon Managed Grafana Workspace]
    GROLE[Grafana Service IAM Role]
  end

  %% Data flow
  SIM -->|MQTT TLS| IOT
  IOT --> RULE
  RULE -->|PutRecord(s)| KDS
  KDS -->|Event source mapping| LAMBDA
  SSM -->|Env vars at deploy/runtime| LAMBDA
  LAMBDA -->|Line Protocol :8086| INFLUX

  %% Network/security relationships
  LAMBDA --- SG1
  INFLUX --- SG2
  SG1 -->|Allowed ingress on 8086| SG2
  RT --> S3EP

  %% Observability path
  USER -->|AWS SSO| GRAFANA
  GRAFANA -->|AssumeRole| GROLE
  GROLE -->|Read metrics/log metadata| CW
```

## Notes

- `main.tf` is currently empty; resources are split by domain-specific files.
- Grafana is currently configured with `CLOUDWATCH` as the datasource.
- The Lambda function is named `kinesis-to-influx`, but its handler file is `kinesis2timestream.py`.
- Public subnets are optional and currently default to none.
