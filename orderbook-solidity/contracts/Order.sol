pragma solidity ^0.8.20;

contract OrderBook {
    enum OrderType {BUY, SELL}

    struct Order {
        uint id;
        address trader;
        uint amount;
        uint price;
        OrderType orderType;
    }

    uint private nextOrderId;
    mapping (uint => Order) public orders;
    Order[] public buyOrders;
    Order[] public sellOrders;

    event OrderPlaced (uint indexed id, address indexed trader, uint amount, uint price, OrderType orderType);
    event OrderCancelled (uint indexed id, address indexed trader);
    event OrderMatched (uint indexed buyOrderId, uint indexed sellOrderId, uint tradeAmount, uint tradePrice);

    function placeOrder (uint amount, uint price, OrderType orderType) external {
        require(amount > 0, "Amount must be greater than 0");
        require(price > 0, "Price must be greater than 0");

        Order memory newOrder = Order(nextOrderId, msg.sender, amount, price, orderType);
        orders[nextOrderId] = newOrder;

        if (orderType == OrderType.BUY) {
            uint i = buyOrders.length;
            buyOrders.push();

            while (i > 0 && buyOrders [i -1].price < newOrder.price) {
                buyOrders[i] = buyOrders [i - 1];
                i--;
            }
            buyOrders[i] = newOrder;
        } else {
            uint i = sellOrders.length;
            sellOrders.push();

            while (i > 0 && sellOrders[i-1].price > newOrder.price) {
                sellOrders[i] = sellOrders[i-1];
                i--;
            }
            sellOrders[i] = newOrder;
        }

        emit OrderPlaced(nextOrderId, msg.sender, amount, price, orderType);
        nextOrderId++;
    }

    function cancelOrder (uint orderId) external {
        require(orders[orderId].trader == msg.sender, "Not order owner");

        delete orders[orderId];

        emit OrderCancelled(orderId, msg.sender);
    }

    function removeOrder (OrderType orderType, uint index) internal {
        if (orderType == OrderType.BUY) {
            require(index < buyOrders.length, "Index out of bounds");
            for (uint i =0; i < buyOrders.length - 1; i++) {
                buyOrders[i] = buyOrders[i + 1];
            }
            buyOrders.pop();
        } else {
            require(index < sellOrders.length, "Index out of bounds");
            for (uint i =0; i < sellOrders.length - 1; i++) {
                sellOrders[i] = sellOrders[i + 1];
            }
            sellOrders.pop();
        }
    }

    function matchOrders() external {
        while (buyOrders.length > 0 && sellOrders.length > 0 && buyOrders[0].price >= sellOrders[0].price) {
            uint tradeAmount = buyOrders[0].amount < sellOrders[0].amount ? buyOrders[0].amount: sellOrders[0].amount;
            uint tradePrice = sellOrders[0].price;

            buyOrders[0].amount -= tradeAmount;
            sellOrders[0].amount -= tradeAmount;

            orders[buyOrders[0].id].amount = buyOrders[0].amount;
            orders[sellOrders[0].id].amount = sellOrders[0].amount;

            emit OrderMatched(buyOrders[0].id, sellOrders[0].id, tradeAmount, tradePrice);


            if (buyOrders[0].amount == 0) {
                removeOrder(OrderType.BUY, 0);
            }
            if (sellOrders[0].amount == 0) {
                removeOrder(OrderType.SELL, 0);
            }

        }
    }
}