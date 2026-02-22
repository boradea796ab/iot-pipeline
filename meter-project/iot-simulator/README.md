# IoT Meter Simulator

This folder contains a modular meter simulator that publishes synthetic readings to AWS IoT Core over MQTT/TLS.

## File Layout

- `simulate_meter.py`
- `meter_sim/`
- `meter_sim/models.py`
- `meter_sim/config.py`
- `meter_sim/ids.py`
- `meter_sim/reading.py`
- `meter_sim/mqtt_client.py`
- `meter_sim/runner.py`
- `certs/`

## Class and Module Responsibilities

### `simulate_meter.py`
- Thin composition root.
- Instantiates classes and wires dependencies.

### `meter_sim/models.py`
- `SimulatorConfig`: immutable runtime configuration.
- `SimulationStats`: runtime counters.

### `meter_sim/config.py`
- `ConfigLoader`: env defaults, CLI parsing, config creation, validation.

### `meter_sim/ids.py`
- `MeterIdFactory`: builds logical meter IDs from config.

### `meter_sim/reading.py`
- `ReadingGenerator`: builds synthetic meter reading payloads.

### `meter_sim/mqtt_client.py`
- `MqttClientFactory`: creates configured MQTT client and TLS wiring.

### `meter_sim/runner.py`
- `SimulationRunner`: executes publish loop.
- `SimulationReporter`: prints summary metrics.

## SOLID and Design Patterns (Practical)

This is now explicitly class-based, but still lightweight (no unnecessary framework layers).

### Single Responsibility Principle (SRP)
- `ConfigLoader` handles config concerns only.
- `ReadingGenerator` handles payload generation only.
- `MqttClientFactory` handles transport setup only.
- `SimulationRunner` handles execution only.

### Open/Closed Principle (OCP)
- You can extend behavior by swapping implementations without changing `simulate_meter.py` flow.
- Example: replace `ReadingGenerator` with a different generator class.

### Liskov Substitution Principle (LSP)
- Components are used via behavior contracts (method signatures), so alternative implementations can be substituted.

### Interface Segregation Principle (ISP)
- Small, focused classes avoid forcing consumers to depend on unrelated methods.

### Dependency Inversion Principle (DIP)
- High-level orchestration depends on component abstractions/behaviors, not on one monolithic script.
- `SimulationRunner` receives its `ReadingGenerator` dependency via constructor injection.

### Patterns Used
- Factory pattern: `MqttClientFactory`, `MeterIdFactory`.
- Composition root: `simulate_meter.py` wires all dependencies.
- Strategy-style swapability: alternative `ReadingGenerator` or runner collaborators can be injected.

## Run

From project root:

```bash
python3 iot-simulator/simulate_meter.py --endpoint <your-iot-endpoint>
```

Or from inside `iot-simulator/`:

```bash
python3 simulate_meter.py --endpoint <your-iot-endpoint>
```

## Run Configurations (CLI Examples)

### 1) 100 meters, 15 minutes, 200 readings/sec

```bash
python3 iot-simulator/simulate_meter.py \
  --endpoint <your-iot-endpoint> \
  --meters 100 \
  --duration-sec 900 \
  --messages-per-sec 200 \
  --qos 1
```

### 2) About 10,000 total readings (single meter)

At `20 readings/sec`, `500 sec` gives about `10,000` messages.

```bash
python3 iot-simulator/simulate_meter.py \
  --endpoint <your-iot-endpoint> \
  --meters 1 \
  --single-meter-id meter-001 \
  --duration-sec 500 \
  --messages-per-sec 20 \
  --qos 1
```

### 3) About 10,000 total readings (100 meters)

At `200 readings/sec`, `50 sec` gives about `10,000` messages distributed across 100 meters.

```bash
python3 iot-simulator/simulate_meter.py \
  --endpoint <your-iot-endpoint> \
  --meters 100 \
  --meter-prefix meter \
  --start-index 1 \
  --duration-sec 50 \
  --messages-per-sec 200 \
  --qos 1
```

### 4) Smoke test

```bash
python3 iot-simulator/simulate_meter.py \
  --endpoint <your-iot-endpoint> \
  --meters 5 \
  --duration-sec 30 \
  --messages-per-sec 10 \
  --qos 0
```

### 5) Soak test

```bash
python3 iot-simulator/simulate_meter.py \
  --endpoint <your-iot-endpoint> \
  --meters 250 \
  --duration-sec 3600 \
  --messages-per-sec 300 \
  --qos 1
```

## Notes

- This refactor keeps runtime publish behavior unchanged.
- Next step can focus on logic improvements (rate control precision, backpressure, retry policy, accurate elapsed metrics).
