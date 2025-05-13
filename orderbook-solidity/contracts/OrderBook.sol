pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Token1 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract Token2 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract OrderBook  {
    using SafeERC20 for IERC20;
    IERC20 public base;
    IERC20 public quote;
    enum OrderType {BUY, SELL}

    struct Order {
        uint256 id;
        address trader;
        bool isBuyOrder;
        uint256 quantity;
        uint256 price;
        bool isFilled;
        address baseToken;
        address quoteToken;
    }

    uint256 private nextOrderId;
    mapping (uint256 => Order) public orders;
    Order[] public buyOrders;
    Order[] public sellOrders;

    event OrderCanceled(
        uint256 indexed id,
        address indexed trader,
        bool isBuyOrder
    );
    event OrderMatched(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 quantity
    );

    constructor() {}

    function placeBuyOrder(
        uint256 quantity,
        uint256 price,
        address baseToken,
        address quoteToken
    ) external {

        uint256 orderId = nextOrderId++;
        uint256 orderValue = price * quantity;

        IERC20 quoteTokenContract = IERC20(quoteToken);
        require(quoteTokenContract.allowance(msg.sender, address(this)) >= orderValue, "Insufficient funds");
        quoteTokenContract.safeTransferFrom(msg.sender, address(this), orderValue);

        Order memory newOrder = Order({
            id: orderId,
            trader: msg.sender,
            isBuyOrder: true,
            price: price,
            quantity: quantity,
            isFilled: false,
            baseToken: baseToken,
            quoteToken: quoteToken
        });

        orders[orderId] = newOrder;
        insertBuyOrder(newOrder);
        matchOrders();
    }

    function placeSellOrder(
        uint256 price,
        uint256 quantity,
        address baseToken,
        address quoteToken
    ) external {

        IERC20 baseTokenContract = IERC20(baseToken);
        require(baseTokenContract.allowance(msg.sender, address(this)) >= quantity, "Insufficient tokens");
        baseTokenContract.safeTransferFrom(msg.sender, address(this), quantity);

        uint256 orderId = nextOrderId++;
        Order memory newOrder = Order({
            id: orderId,
            trader: msg.sender,
            isBuyOrder: false,
            price: price,
            quantity: quantity,
            isFilled: false,
            baseToken: baseToken,
            quoteToken: quoteToken
        });
        orders[orderId] = newOrder;
        insertSellOrder(newOrder);
        matchOrders();
    }

    function cancelOrder (uint256 orderId, bool isBuyOrder) external {
        Order storage order = orders[orderId];

        require(order.trader == msg.sender, "Not order owner");
        require(!order.isFilled, "Order already filled");

        order.isFilled = true;

        IERC20 baseTokenContract = IERC20(order.baseToken);

        IERC20 quoteTokenContract = IERC20 (order.quoteToken);
        if (order.isBuyOrder) {
            quoteTokenContract.safeTransfer(msg.sender, order.price * order.quantity);
        } else {
            baseTokenContract.safeTransfer(msg.sender, order.quantity);
        }

    emit OrderCanceled(orderId, msg.sender, isBuyOrder);
    }

    function matchOrders() internal {
        while (buyOrders.length > 0 && sellOrders.length > 0) {
            Order storage buyOrder = buyOrders[0];
            Order storage sellOrder = sellOrders[0];

            if (buyOrder.price < sellOrder.price) break;

            uint256 tradeQty = min (buyOrder.quantity, sellOrder.quantity);
            uint256 tradeValue = (tradeQty * sellOrder.price) / 1e18;

            IERC20 baseTokenContract = IERC20 (buyOrder.baseToken);
            IERC20 quoteTokenContract = IERC20 (buyOrder.quoteToken);

            baseTokenContract.safeTransfer(buyOrder.trader, tradeQty);
            quoteTokenContract.safeTransfer(sellOrder.trader, tradeValue);

            buyOrder.quantity -= tradeQty;
            sellOrder.quantity -= tradeQty;
            orders[buyOrder.id].quantity = buyOrder.quantity;
            orders[sellOrder.id].quantity = sellOrder.quantity;

            if (buyOrder.quantity == 0) {
                orders[buyOrder.id].isFilled = true;
                _removeOrderFromArray(buyOrders, 0);
            }

            if (sellOrder.quantity == 0){
                orders[sellOrder.id].isFilled = true;
                _removeOrderFromArray(sellOrders, 0);
            }
            emit OrderMatched(
                buyOrder.id,
                sellOrder.id,
                buyOrder.trader,
                sellOrder.trader,
                sellOrder.price,
                tradeQty
            );
        }
    }

    function getBuyOrderIndex (uint256 orderId) public view returns (uint256) {
        require(orderId < buyOrders.length, "Order ID out of range");
        return orderId;
    }

    function getSellOrderIndex (uint256 orderId) public view returns (uint256) {
        require(orderId < sellOrders.length, "Order ID out of range");
        return orderId;
    }

    function insertBuyOrder(Order memory newOrder) internal {
        uint256 i = buyOrders.length;

        buyOrders.push(newOrder);

        while (i >0 && buyOrders[i - 1].price < newOrder.price) {
            buyOrders[i] = buyOrders [i - 1];

            i--;
        }

        buyOrders[i] = newOrder;
    }

    function insertSellOrder(Order memory newOrder) internal {
        uint256 i = sellOrders.length;

        sellOrders.push(newOrder);

        while (i > 0 && sellOrders[i - 1].price > newOrder.price) {
            sellOrders[i] = sellOrders [i - 1];

            i--;
        }

        sellOrders[i] = newOrder;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _removeOrderFromArray(Order[] storage arr, uint256 index) internal {
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }

    function buyOrdersLength() external view returns (uint256) {
        return buyOrders.length;
    }

    function sellOrdersLength() external view returns (uint256) {
        return sellOrders.length;
    }
}