PYTEST_FLAGS ?=
ifeq ($(VERBOSE),1)
	PYTEST_FLAGS += -vv -s
endif

test:
	pytest $(PYTEST_FLAGS) terraform/modules/lambda_consumer/tests

build:
	cd terraform/modules/lambda_consumer && ./build_lambdas.sh

plan:
	cd terraform && terraform plan

deploy: test build plan
	@echo "Run 'terraform apply' manually once you're ready."
