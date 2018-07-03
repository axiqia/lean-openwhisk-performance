# Performance evaluation for Lean Apache OpenWhisk
A simple performance test for [`Lean OpenWhisk`](https://github.com/kpavel/incubator-openwhisk/tree/lean) . Determines throughput and end-user latency of the system.

## Test setup
- A Lean OpenWhisk system is deployed.
- [`loadtest`](https://www.npmjs.com/package/loadtest) module installed on the machine where test.sh will be executed.
- (Optional in case OW running on remote machine) SSH password-less access configured (using SSH keys) from machine where test.sh is running to machine where Lean OpenWhisk instance

### Test flow
Based on input parameters the test iterates over payloads, ow and load concurrencies, e.g.
