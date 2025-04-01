import {ethers} from "hardhat";

async function main() {
    const OrderBook = await ethers.getContractFactory("OrderBook");
    const orderBook = await OrderBook.deploy();

    await orderBook.waitForDeployment();
    console.log(`OrderBook deployed to : ${await orderBook.getAddress()}`);
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    })