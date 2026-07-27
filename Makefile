.PHONY: platform-up platform-down bootstrap-addons deploy-staging render-staging

platform-up:
	@chmod +x scripts/*.sh
	@./scripts/make-target.sh platform-up

platform-down:
	@chmod +x scripts/*.sh
	@./scripts/make-target.sh platform-down

bootstrap-addons:
	@chmod +x scripts/*.sh
	@./scripts/make-target.sh bootstrap-addons

deploy-staging:
	@chmod +x scripts/*.sh
	@./scripts/make-target.sh deploy-staging

render-staging:
	@chmod +x scripts/*.sh
	@./scripts/make-target.sh render-staging --dummy
