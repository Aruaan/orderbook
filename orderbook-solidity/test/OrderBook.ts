import { ethers } from "hardhat";
import { expect } from "chai";
import { OrderBook } from "../typechain-types";

describe("OrderBook", function () {
    let orderBook: OrderBook;
    let owner: any;
    let trader: any;

    beforeEach(async function () {
        [owner, trader] = await ethers.getSigners();
        const OrderBookFactory = await ethers.getContractFactory("OrderBook");
        orderBook = (await OrderBookFactory.deploy()) as unknown as OrderBook;
        await orderBook.waitForDeployment();
    });

    it("Should place a buy order correctly", async function () {
        await expect(orderBook.connect(trader).placeOrder(100, 10, 0))
            .to.emit(orderBook, "OrderPlaced")
            .withArgs(0, trader.address, 100, 10, 0);

        const order = await orderBook.orders(0);
        expect(order.trader).to.equal(trader.address);
        expect(order.amount).to.equal(100);
        expect(order.price).to.equal(10);
        expect(order.orderType).to.equal(0); // BUY
    });

    it("Should place a sell order correctly", async function () {
        await expect(orderBook.connect(trader).placeOrder(50, 20, 1))
            .to.emit(orderBook, "OrderPlaced")
            .withArgs(0, trader.address, 50, 20, 1);

        const order = await orderBook.orders(0);
        expect(order.trader).to.equal(trader.address);
        expect(order.amount).to.equal(50);
        expect(order.price).to.equal(20);
        expect(order.orderType).to.equal(1); // SELL
    });

    it("Should cancel an order", async function () {
        await orderBook.connect(trader).placeOrder(100, 10, 0);
        await expect(orderBook.connect(trader).cancelOrder(0))
            .to.emit(orderBook, "OrderCancelled")
            .withArgs(0, trader.address);

        const order = await orderBook.orders(0);
        expect(order.trader).to.equal(ethers.ZeroAddress);
    });

    it("Should match orders correctly", async function () {
        await orderBook.connect(trader).placeOrder(100, 10, 0); // BUY Order
        await orderBook.connect(owner).placeOrder(100, 10, 1); // SELL Order

        await expect(orderBook.matchOrders())
            .to.emit(orderBook, "OrderMatched")
            .withArgs(0, 1, 100, 10);

        const buyOrder = await orderBook.orders(0);
        const sellOrder = await orderBook.orders(1);

        expect(buyOrder.amount).to.equal(0);
        expect(sellOrder.amount).to.equal(0);
    });
});
