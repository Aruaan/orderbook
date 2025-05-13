import { ethers } from "hardhat";
import { expect } from "chai";
import { OrderBook, Token1, Token2} from "../typechain-types";
import { Signer } from "ethers";

describe("OrderBook", function () {
    let orderBook: OrderBook;
    let token1: Token1;
    let token2: Token2;
    let owner: Signer;
    let trader: Signer;

    beforeEach(async () => {
        [owner, trader] = await ethers.getSigners();

        const Token1Factory = await ethers.getContractFactory("Token1");
        token1 = await Token1Factory.connect(owner).deploy("Token1", "TK1", ethers.parseEther("100000")) as Token1;
        await token1.waitForDeployment();

        const Token2 = await ethers.getContractFactory("Token2");
        token2 = await Token2.connect(owner).deploy("Token2", "TK2", ethers.parseEther("100000"));
        await token2.waitForDeployment();

        const OrderBook = await ethers.getContractFactory("OrderBook");
        orderBook = await OrderBook.deploy();
        await orderBook.waitForDeployment();

        // Transfer tokens to trader
        await token1.connect(owner).transfer(await trader.getAddress(), ethers.parseEther("1000"));
        await token2.connect(owner).transfer(await trader.getAddress(), ethers.parseEther("1000"));

        // Approve after transfer
        await token1.connect(trader).approve(orderBook.target, ethers.MaxUint256);
        await token2.connect(trader).approve(orderBook.target, ethers.MaxUint256);
    });

    it("Should place a buy order", async () => {
        const quantity = ethers.parseEther("10");
        const price = 2n;

        await token2.connect(trader).approve(orderBook.target, price * quantity);

        await orderBook.connect(trader).placeBuyOrder(
            quantity,
            price,
            token1.target,
            token2.target
        );

        const order = await orderBook.orders(0);
        expect(order.trader).to.equal(await trader.getAddress());
        expect(order.quantity).to.equal(quantity);
        expect(order.price).to.equal(price);
        expect(order.isBuyOrder).to.be.true;
    });

    it("Should place a sell order", async () => {
        const quantity = ethers.parseEther("5");
        const price = 3n;

        await token1.connect(trader).approve(orderBook.target, quantity);

        await orderBook.connect(trader).placeSellOrder(
            price,
            quantity,
            token1.target,
            token2.target
        );

        const order = await orderBook.orders(0);
        expect(order.trader).to.equal(await trader.getAddress());
        expect(order.quantity).to.equal(quantity);
        expect(order.price).to.equal(price);
        expect(order.isBuyOrder).to.be.false;
    });

    it("Should match buy and sell orders", async () => {
        const quantity = ethers.parseEther("10");
        const price = 2n;

        await token2.connect(trader).approve(orderBook.target, price * quantity);
        await token1.connect(owner).approve(orderBook.target, quantity);

        // Place BUY from trader
        await orderBook.connect(trader).placeBuyOrder(
            quantity,
            price,
            token1.target,
            token2.target
        );

        // Place SELL from owner
        await orderBook.connect(owner).placeSellOrder(
            price,
            quantity,
            token1.target,
            token2.target
        );

        // Check mapping storage
        const buyOrder = await orderBook.orders(0);
        const sellOrder = await orderBook.orders(1);
        expect(buyOrder.quantity).to.equal(0);
        expect(sellOrder.quantity).to.equal(0);
        expect(buyOrder.isFilled).to.be.true;
        expect(sellOrder.isFilled).to.be.true;

        // Check array lengths
        expect(await orderBook.buyOrdersLength()).to.equal(0);
        expect(await orderBook.sellOrdersLength()).to.equal(0);
    });


    it("Should cancel an order", async () => {
        const quantity = ethers.parseEther("5");
        const price = 1n;

        await token2.connect(trader).approve(orderBook.target, price * quantity);

        await orderBook.connect(trader).placeBuyOrder(
            quantity,
            price,
            token1.target,
            token2.target
        );

        const initialBalance = await token2.balanceOf(await trader.getAddress());

        await orderBook.connect(trader).cancelOrder(0, true);

        const order = await orderBook.orders(0);
        expect(order.isFilled).to.be.true;

        // Check if funds were returned
        const finalBalance = await token2.balanceOf(await trader.getAddress());
        expect(finalBalance).to.equal(initialBalance + (price * quantity));
    });

});