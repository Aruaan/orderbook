pragma solidity ^0.8.20;

contract OrderBook {
    enum OrderType {BUY, SELL}

    struct Order {
        uint id;
        address trader;
        uint amount;
        uint price;
        OrderType orderType;
        bool isFilled;
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

        Order memory newOrder = Order(nextOrderId, msg.sender, amount, price, orderType, false);
        orders[nextOrderId] = newOrder;

        if (orderType == OrderType.BUY) {
            buyOrders.push(newOrder);
        } else {
            sellOrders.push(newOrder);
        }

        emit OrderPlaced(nextOrderId, msg.sender, amount, price, orderType);
        nextOrderId++;
    }

    function cancelOrder (uint orderId) external {
        require(orders[orderId].trader == msg.sender, "Not order owner");
        require(!orders[orderId].isFilled, "Order already filled");

        delete orders[orderId];

        emit OrderCancelled(orderId, msg.sender);
    }

    function matchOrders() external {
        for (uint i = 0; i < buyOrders.length; i++) {
            for (uint j = 0; i <sellOrders.length; j++){
                if (buyOrders[i].price >= sellOrders[j].price && !buyOrders[i].isFilled && !sellOrders[j].isFilled) {
                    uint tradeAmount = buyOrders[i].amount < sellOrders[j].amount ? buyOrders[i].amount: sellOrders[j].amount;
                    uint tradePrice = sellOrders[j].price;

                    buyOrders[i].amount -= tradeAmount;
                    sellOrders[j].amount -= tradeAmount;

                    if (buyOrders[i].amount == 0) buyOrders[i].isFilled = true;
                    if (sellOrders[j].amount == 0) sellOrders[j].isFilled = true;

                    emit OrderMatched(buyOrders[i].id, sellOrders[j].id, tradeAmount, tradePrice);
                }
            }
        }
    }
}