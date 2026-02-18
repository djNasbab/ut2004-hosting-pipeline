IMAGE      := ut2004-server
TAG        := latest
STACK_NAME := ut2004-server
AWS_REGION := $(shell aws configure get region 2>/dev/null || echo eu-north-1)
ACCOUNT_ID  = $(shell aws sts get-caller-identity --query Account --output text)
ECR_URI     = $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(IMAGE)

# ── Local ──────────────────────────────────────────────────────

.PHONY: build run stop logs clean

build:
	docker build --platform linux/amd64 -t $(IMAGE):$(TAG) .

run:
	docker compose up -d

stop:
	docker compose down

logs:
	docker compose logs -f ut2004

clean:
	docker compose down -v
	docker rmi $(IMAGE):$(TAG) 2>/dev/null || true

# ── AWS ────────────────────────────────────────────────────────

.PHONY: deploy push server-ip aws-logs teardown

deploy:
	aws cloudformation deploy \
	  --template-file cloudformation.yml \
	  --stack-name $(STACK_NAME) \
	  --capabilities CAPABILITY_NAMED_IAM \
	  --region $(AWS_REGION)

push: build
	aws ecr get-login-password --region $(AWS_REGION) \
	  | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker tag $(IMAGE):$(TAG) $(ECR_URI):$(TAG)
	docker push $(ECR_URI):$(TAG)
	@echo "\nImage pushed. Restarting ECS service to pick up the new image..."
	aws ecs update-service \
	  --cluster ut2004 \
	  --service ut2004-server \
	  --force-new-deployment \
	  --region $(AWS_REGION) \
	  --query 'service.serviceName' --output text

server-ip:
	@TASK_ARN=$$(aws ecs list-tasks --cluster ut2004 --service ut2004-server \
	  --query 'taskArns[0]' --output text --region $(AWS_REGION)); \
	ENI=$$(aws ecs describe-tasks --cluster ut2004 --tasks $$TASK_ARN \
	  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
	  --output text --region $(AWS_REGION)); \
	aws ec2 describe-network-interfaces --network-interface-ids $$ENI \
	  --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region $(AWS_REGION)

aws-logs:
	aws logs tail /ecs/ut2004-server --follow --region $(AWS_REGION)

teardown:
	aws cloudformation delete-stack --stack-name $(STACK_NAME) --region $(AWS_REGION)
	@echo "Stack deletion initiated. Run 'aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME)' to wait."
