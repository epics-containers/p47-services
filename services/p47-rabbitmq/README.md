# RabbitMQ Setup

Follow the steps below to configure RabbitMQ for the `p47-beamline` namespace.

## 1.  Create Secrets

Create a sealed secrets using kubeseal for `rabbitmq-erlang-cookie`, which is used to maintain state and prevent RabbitMQ restarting prematurely.

Use [`kubeseal`](https://github.com/bitnami-labs/sealed-secrets?tab=readme-ov-file#raw-mode-experimental) in raw mode to seal the secret.
This command generates a random string and seals it with kubeseal which are then safe to commit to public repositories.

```bash
$ # module load k8s-p47
$ head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 | kubeseal --raw --namespace p47-beamline --name rabbitmq-secrets
```

This will output a sealed string. Add the resulting output into the appropriate field in `templates/secret.yaml`.

---

## 2. Configure Domain Name (Recommended)

Request a static IP mapped from a DNS entry from the Scientific Computing help desk.

Once assigned, set the static IP under the `loadBalancerIP` field in your `values.yaml` file.

`p47-rabbitmq-daq.diamond.ac.uk -> Static IP` this mapping allows processes outside of the namespace e.g. Analysis to access data from rabbitmq.
