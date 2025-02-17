// Verification of GasBadNftMarketPlace

/////////////////
////  USING  ////
/////////////////
using GasBadNftMarketplace as gasBadMarket; 
using NftMarketplace as market;


///////////////////
////  METHODS  ////
///////////////////
methods {
    // Summary Functions
    function _.safeTransferFrom(address,address,uint256) external => DISPATCHER(true);
    function _.onERC721Received(address,address,uint256,bytes) external => DISPATCHER(true);

    // View Functions
    function getListing(address,uint256) external returns (INftMarketplace.Listing) envfree;
    function getProceeds(address) external returns (uint256) envfree;
}


//////////////////
////  GHOSTS  ////
//////////////////
ghost mathint listingUpdatesCount {
    init_state axiom listingUpdatesCount == 0;
}

ghost mathint log4Count {
    init_state axiom log4Count == 0;
}

/////////////////
////  HOOKS  ////
/////////////////
hook Sstore s_listings[KEY address nftAddress][KEY uint256 tokenId].price uint256 price {
    listingUpdatesCount = listingUpdatesCount + 1;
}

hook LOG4(uint offset, uint length, bytes32 t1, bytes32 t2, bytes32 t3, bytes32 t4) {
    log4Count = log4Count + 1;
}

////////////////////////////
////  INVARIANTS/RULES  ////
////////////////////////////
invariant anytime_mapping_updated_emit_event()
    listingUpdatesCount <= log4Count;

rule calling_any_function_should_result_in_each_contract_having_the_same_state(method f, method f2) 
{
    // Arrange
    require(f.selector == f2.selector);
    env e;
    calldataarg args;
    address listingAddr;
    uint256 tokenId;
    address seller;

    require(gasBadMarket.getProceeds(e, seller) == market.getProceeds(e, seller));
    require(gasBadMarket.getListing(e, listingAddr, tokenId).price == market.getListing(e, listingAddr, tokenId).price);
    require(gasBadMarket.getListing(e, listingAddr, tokenId).seller == market.getListing(e, listingAddr, tokenId).seller);

    // Act
    gasBadMarket.f(e, args);
    market.f2(e, args);

    // Assert
    assert(gasBadMarket.getProceeds(e, seller) == market.getProceeds(e, seller));
    assert(gasBadMarket.getListing(e, listingAddr, tokenId).price == market.getListing(e, listingAddr, tokenId).price);
    assert(gasBadMarket.getListing(e, listingAddr, tokenId).seller == market.getListing(e, listingAddr, tokenId).seller);
}