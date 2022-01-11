import pytest
from brownie import config
from brownie import Contract
from brownie_tokens import MintableForkToken

@pytest.fixture(scope="module", autouse=True)
def shared_setup(module_isolation):
        pass

@pytest.fixture
def gov(accounts):
    yield accounts.at("0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52", force=True)


@pytest.fixture
def user(accounts):
    yield accounts[0]


@pytest.fixture
def rewards(accounts):
    yield accounts.at("0x93A62dA5a14C80f265DAbC077fCEE437B1a0Efde", force=True)


@pytest.fixture
def guardian(accounts):
    yield accounts[2]


@pytest.fixture
def management(accounts):
    yield accounts[3]


@pytest.fixture
def strategist(accounts):
    yield accounts[4]


@pytest.fixture
def keeper(accounts):
    yield accounts[5]


@pytest.fixture
def token():
    token_address = "0xAA5A67c256e27A5d80712c51971408db3370927D"
    yield Contract(token_address)


@pytest.fixture
def usdc():
    token_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    yield Contract(token_address)


@pytest.fixture
def usdt():
    token_address = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    yield Contract(token_address)


@pytest.fixture
def dai():
    token_address = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    yield Contract(token_address)


@pytest.fixture
def crv():
    token_address = "0xD533a949740bb3306d119CC777fa900bA034cd52"
    yield Contract(token_address)


@pytest.fixture
def cvx():
    token_address = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B"
    yield Contract(token_address)


@pytest.fixture
def amount(accounts, token, user):
    amount = 10_000 * 10 ** token.decimals()
    # In order to get some funds for the token you are about to use,
    # it impersonate an exchange address to use it's funds.
    token = MintableForkToken(token.address)
    token._mint_for_testing(user, amount)
    yield amount


@pytest.fixture
def weth():
    token_address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    yield Contract(token_address)


@pytest.fixture
def weth_amout(user, weth):
    weth_amout = 10 ** weth.decimals()
    user.transfer(weth, weth_amout)
    yield weth_amout


@pytest.fixture
def vault(pm, gov, rewards, guardian, management, token):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(token, gov, rewards, "", "", guardian, management, {'from':gov})
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    yield vault

@pytest.fixture
def strategy(strategist, keeper, vault, Strategy, gov, dai, usdt):

    strategy = strategist.deploy(Strategy, vault, dai, [1, 1], [3000, 3000, 3000], [usdt, dai], [3000, 3000], [1e24, 10000, 43200, 259200, 1000, 1000])

    strategy.setKeeper(keeper, {'from': gov})

    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    yield strategy

@pytest.fixture
def rewards_pool(strategy):
    yield Contract(strategy.rewardsPool())


@pytest.fixture(scope="session")
def RELATIVE_APPROX():
    yield 1e-3
