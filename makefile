-include .env

build:
	forge build

test:
	forge test --via-ir

deploySponsor:
	@echo "Deploying to $(chain)"
	@echo "Broadcast and verify are commented for security reasons, dont forget to uncomment them."
	forge script script/DeployQstmeSponsor.s.sol:DeployQstmeSponsorScript \
	$(chain) \
	--sig "run(string)" \
	--via-ir \
	-vvvv \
	--etherscan-api-key ${OPTIMISM_API_KEY} \
#	--broadcast \
#	--verify \
