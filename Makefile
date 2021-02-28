.DEFAULT_GOAL := help


# >> Setup lazy variables

BOT_TOKEN=$(shell gopass show personal/bots/manga-to-kindle token)
AWS_ACCOUNT_ID=$(shell gopass show personal/aws/Administrator/amazon.com 'Account ID')
MANGADEX_USERNAME=$(shell gopass show personal/mangadex.org username)
MANGADEX_PASSWORD=$(shell gopass show --password personal/mangadex.org)
FROM_EMAIL=mtk@bythe.rocks
TO_EMAIL=$(shell gopass show personal/google.com username)

# Make the expensive variables lazy
make-lazy = $(eval $1 = $$(eval $1 := $(value $(1)))$$($1))

$(call make-lazy,BOT_TOKEN)
$(call make-lazy,AWS_ACCOUNT_ID)
$(call make-lazy,MANGADEX_USERNAME)
$(call make-lazy,MANGADEX_PASSWORD)
$(call make-lazy,TO_EMAIL)



#help:	@ List available tasks on this project
.PHONY: help
help:
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST) | tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#run: @ Run the app locally
.PHONY: run
run: deps.install test.lint
	BOT_TOKEN="111" \
	 BOT_HOOK_PATH="111" \
	 MANGADEX_USERNAME="$(MANGADEX_USERNAME)" \
	 MANGADEX_PASSWORD="$(MANGADEX_PASSWORD)" \
	 FROM_EMAIL="mtk@bythe.rocks" \
	 TO_EMAIL="$(TO_EMAIL)" \
	 DEBUG="*" \
	 AWS_REGION="eu-west-3" \
	 ts-node -e 'import * as manga from "./src/manga"; \
	 import * as email from "./src/email"; \
	 async function main() { \
	     const info = await manga.getMangaInfo(1218516); \
	     await email.emailMangaInfo(info); \
	 }; main();'

#deps.install: @ Install dependencies
.PHONY: deps.install
deps.install:
	npm install

#build: @ Build the project
.PHONY: build
build: deps.install
	npx webpack

#test.lint: @ Lint the project
.PHONY: test.lint
test.lint: deps.install
	npx tslint -c tslint.json 'src/**/*.ts'

#deploy: @ Deploy the bot to AWS Lambda
.PHONY: deploy
deploy: build test.lint deploy.init deploy.apply

#deploy.init: @ Initialize terraform
.PHONY: deploy.init
deploy.init:
	cd infra; terraform init

#deploy.apply: @ Apply the terraform
.PHONY: deploy.apply
deploy.apply:
	cd infra; terraform apply \
		                -var "bot_token=$(BOT_TOKEN)" \
						-var "account_id=$(AWS_ACCOUNT_ID)" \
						-var "mangadex_username=$(MANGADEX_USERNAME)" \
						-var "mangadex_password=$(MANGADEX_PASSWORD)" \
						-var "from_email=$(FROM_EMAIL)" \
						-var "to_email=$(TO_EMAIL)"
	curl "https://api.telegram.org/bot$(BOT_TOKEN)/setWebHook?url=$$(cd infra; terraform output webhook_url)"

