-include .env

build:
	forge build

test:
	forge test --via-ir

deploySponsor:
	forge script script/DeployQstmeSponsor.s.sol:DeployQstmeSponsorScript \
	$(chain) \
	--sig "run(string)" \
	--via-ir \
	-vvvv \
	--etherscan-api-key ${BASESCAN_API_KEY} \
# 	--broadcast \
# 	--verify \

deployReward:
	forge script script/DeployQstmeReward.s.sol:DeployQstmeRewardScript \
	$(chain) \
	--sig "run(string)" \
	--via-ir \
	-vvvv \
	--etherscan-api-key ${BASESCAN_API_KEY} \
# 	--broadcast \
# 	--verify \

deployMockUsdt:
	@echo "Deploying to $(chain)"
	@echo "Broadcast and verify are commented for security reasons, dont forget to uncomment them."
	forge script script/DeployMockUSDT.s.sol:DeployMockUSDTScript \
	$(chain) \
	--sig "run(string)" \
	--via-ir \
	-vvvv \
	--etherscan-api-key ${BASESCAN_API_KEY} \
# 	--broadcast \
# 	--verify \

resetAndSponsor: forge script script/ResetAndSponsor.s.sol\:ResetAndSponsorScript \
    $(chain) \
    --sig "run(string)" \
    --via-ir \
    -vvvv \
# 	--broadcast \

sendSponsorship: forge script script/SendSponsorship.s.sol\:SendSponsorshipScript \
    $(chain) \
    --sig "run(string)" \
    --via-ir \
    -vvvv \
# 	--broadcast \

sendReward: forge script script/SendReward.s.sol\:SendRewardScript \
    $(chain) $(recipient) \
    --sig "run(string)" \
    --via-ir \
    -vvvv \
# 	--broadcast \
