
/// Module: market_maker
module market_maker::market_maker;
use sui::event;


// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

// Event emitted when orders are matched
public struct OrderMatched has copy, drop {
    bid_maker: address,
    ask_maker: address,
    amount: u64,
    price: u64
}

public struct Token<phantom X> has store {}

public struct Order<X> has key, store {
    id: UID,
    maker: address,
    is_bid: bool,
    price: u64,
    amount: u64,
    token: Token<X>
}

public struct OrderBook< X: store, Y: store> has key, store {
    id: UID,
    bids: Table<u64, vector<Order<X>>>,
    asks: Table<u64, vector<Order<Y>>>,
    best_bid: u64,
    best_ask: u64
}

// Create a new order book
public entry fun create_order_book<X:store, Y:store>(ctx: &mut TxContext) {
    let order_book = OrderBook<X, Y> {
        id: object::new(ctx),
        bids: vector::empty<Order<X>>(),
        asks: vector::empty<Order<Y>>()
    };
    transfer::share_object(order_book);
}

// Function to place a bid order (using token type X)
public fun place_bid<X: store, Y: store>(
    book: &mut OrderBook<X, Y>,
    price: u64,
    amount: u64,
    token: Token<X>,
    ctx: &mut TxContext
) {
    let id = object::new(ctx);
    let order = Order {
        id,
        maker: tx_context::sender(ctx),
        is_bid: true,
        price,
        amount,
        token,
    };
    vector::push_back(&mut book.bids, order);
    event::emit(event);
}

// Function to place an ask order (using token type Y)
public fun place_ask<X: store, Y: store>(
    book: &mut OrderBook<X, Y>,
    price: u64,
    amount: u64,
    token: Token<Y>,
    ctx: &mut TxContext
): Order<Y> {
    let id = object::new(ctx);
    let order = Order {
        id,
        maker: tx_context::sender(ctx),
        is_bid: false,
        price,
        amount,
        token,
    };
    vector::push_back(&mut book.asks, order);
    order
}

public entry fun match_orders<X:store, Y:store>(book: &mut OrderBook<X, Y>, ctx: &mut TxContext) {
    // Sort bids (highest price first)
    sort_bids(&mut book.bids);
    
    // Sort asks (lowest price first)
    sort_asks(&mut book.asks);
    
    let i = 0;
    let j = 0;
    
    while (i < vector::length(&book.bids) && j < vector::length(&book.asks)) {
        let bid = vector::borrow(&book.bids, i);
        let ask = vector::borrow(&book.asks, j);
        
        // Check if there's a match (bid price >= ask price)
        if (bid.price >= ask.price) {
            // Calculate the matched amount (minimum of bid and ask amounts)
            let matched_amount = if (bid.amount < ask.amount) bid.amount else ask.amount;
            
            // Process the match
            process_match<X, Y>(
                book,
                i,
                j,
                matched_amount,
                ask.price, // Use ask price for execution
                ctx
            );
            
            // If bid is completely filled, move to next bid
            if (vector::borrow(&book.bids, i).amount == 0) {
                i = i + 1;
            };
            
            // If ask is completely filled, move to next ask
            if (j < vector::length(&book.asks) && vector::borrow(&book.asks, j).amount == 0) {
                j = j + 1;
            };
        } else {
            // No more possible matches
            break;
        };
    };
    
    // Clean up filled orders
    clean_filled_orders(&mut book.bids);
    clean_filled_orders(&mut book.asks);
}

// Helper function to process a match
fun process_match<X:store, Y:store>(
    book: &mut OrderBook<X, Y>,
    bid_idx: u64,
    ask_idx: u64,
    amount: u64,
    execution_price: u64,
    ctx: &mut TxContext
) {
    let bid = vector::borrow_mut(&mut book.bids, bid_idx);
    let ask = vector::borrow_mut(&mut book.asks, ask_idx);
    
    // Update the amounts
    bid.amount = bid.amount - amount;
    ask.amount = ask.amount - amount;
    
    // Emit event for the match
    event::emit(OrderMatched {
        bid_maker: bid.maker,
        ask_maker: ask.maker,
        amount,
        price: execution_price
    });
    
    // Note: Actual token transfers would go here
    // This would require additional logic depending on your token implementation
}

// Helper function to sort bids (highest price first)
fun sort_bids<X>(bids: &mut vector<Order<X>>) {
    let len = vector::length(bids);
    if (len <= 1) {
        return
    };
    
    let i = 0;
    while (i < len - 1) {
        let j = 0;
        while (j < len - i - 1) {
            let order1 = vector::borrow(bids, j);
            let order2 = vector::borrow(bids, j + 1);
            
            // For bids, higher price comes first (descending order)
            if (order1.price < order2.price) {
                vector::swap(bids, j, j + 1);
            };
            j = j + 1;
        };
        i = i + 1;
    };
}

// Helper function to sort asks (lowest price first)
fun sort_asks<Y>(asks: &mut vector<Order<Y>>) {
    let len = vector::length(asks);
    if (len <= 1) {
        return
    };
    
    let i = 0;
    while (i < len - 1) {
        let j = 0;
        while (j < len - i - 1) {
            let order1 = vector::borrow(asks, j);
            let order2 = vector::borrow(asks, j + 1);
            
            // For asks, lower price comes first (ascending order)
            if (order1.price > order2.price) {
                vector::swap(asks, j, j + 1);
            };
            j = j + 1;
        };
        i = i + 1;
    };
}

// Helper function to remove filled orders (amount = 0)
fun clean_filled_orders<T>(orders: &mut vector<Order<T>>) {
    let i = 0;
    while (i < vector::length(orders)) {
        if (vector::borrow(orders, i).amount == 0) {
            // Remove the filled order
            // In a real implementation, you would need to handle the order deletion properly
            let _removed_order = vector::remove(orders, i);
            // You might want to transfer the Order object back to its maker or handle it differently
        } else {
            i = i + 1;
        };
    };
}

// Add a function to cancel an order
public entry fun cancel_order<X:store, Y:store>(
    book: &mut OrderBook<X, Y>, 
    order_idx: u64, 
    is_bid: bool,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    
    if (is_bid) {
        // Ensure the order exists
        assert!(order_idx < vector::length(&book.bids), 0);
        
        // Ensure the order belongs to the sender
        let order = vector::borrow(&book.bids, order_idx);
        assert!(order.maker == sender, 1);
        
        // Remove the order
        let removed_order = vector::remove(&mut book.bids, order_idx);
        
        // In a real implementation, you would return the token to the maker
        // For example: transfer::transfer(removed_order.token, sender);
        
        // Clean up the order object
        let Order { id, maker: _, is_bid: _, price: _, amount: _, token: _ } = removed_order;
        object::delete(id);
    } else {
        // Similar logic for asks
        assert!(order_idx < vector::length(&book.asks), 0);
        
        let order = vector::borrow(&book.asks, order_idx);
        assert!(order.maker == sender, 1);
        
        let removed_order = vector::remove(&mut book.asks, order_idx);
        
        // Clean up the order object
        let Order { id, maker: _, is_bid: _, price: _, amount: _, token: _ } = removed_order;
        object::delete(id);
    };
}

// Get best bid price
public fun get_best_bid<X:store, Y:store>(book: &OrderBook<X, Y>): (u64, bool) {
    let bids = &book.bids;
    let len = vector::length(bids);
    
    if (len == 0) {
        return (0, false)
    };
    
    let best_price = 0;
    let best_idx = 0;
    
    let i = 0;
    while (i < len) {
        let bid = vector::borrow(bids, i);
        if (bid.price > best_price) {
            best_price = bid.price;
            best_idx = i;
        };
        i = i + 1;
    };
    
    (vector::borrow(bids, best_idx).price, true)
}

// Get best ask price
public fun get_best_ask<X:store, Y:store>(book: &OrderBook<X, Y>): (u64, bool) {
    let asks = &book.asks;
    let len = vector::length(asks);
    
    if (len == 0) {
        return (0, false)
    };
    
    let best_price = 18446744073709551615; // u64 max value
    let best_idx = 0;
    
    let i = 0;
    while (i < len) {
        let ask = vector::borrow(asks, i);
        if (ask.price < best_price) {
            best_price = ask.price;
            best_idx = i;
        };
        i = i + 1;
    };
    
    (vector::borrow(asks, best_idx).price, true)
}
