.PHONY: all
all: get_credentials create_namespace

get_credentials:
	@echo "Getting Kubernetes Engine cluster credentials..."
	gcloud container clusters get-credentials hash-challenge-kubernetes-engine --zone us-east1-b

create_namespace:
	@echo "Creating checkout namespace & applying the Istio injection label..."
	kubectl create namespace checkout
	kubectl label namespaces checkout istio-injection=enabled

clean:
	@echo "Deleting Terraform resources..."
	terraform destroy -auto-approve
