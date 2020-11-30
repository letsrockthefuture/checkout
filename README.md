# Checkout (5rd)

Checkout is the new microservice that will handle the checkout of our friend Monolith, and that was developed following the infrastructure standard as code using Terraform.

## Usage

Get the Google Kubernetes Engine cluster credentials & create the checkout namespace with Istio injection label:

```bash
make
```

Initializing Terraform and applying it's settings:

```bash
terraform init
terraform apply
```

To clean:

```bash
make clean
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.
