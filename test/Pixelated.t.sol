// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/Pixelated.sol";

contract PixelatedTest is Test {

    string RPC = 'https://rpc2.alto.build';
    uint256 fork;

    Pixelated public nft;

    address public admin = address(0xad1);
    address public alice = address(0xa11ce);
    address public bob = address(0xb0b);

    function setUp() public {
        fork = vm.createSelectFork(RPC);

        vm.startPrank(admin);
            nft = new Pixelated();
        vm.stopPrank();
    }

    function testAcceptAndMintOne() public {
        vm.deal(bob, 1000 ether);
        
        vm.startPrank(bob);
            nft.accept("I understand that by holding this NFT I have a duty to cherish it. If I fail to do so, it will perish and it will be my fault.");
            nft.mint{value: 10 * 1.337 ether}();

            assertEq(nft.balanceOf(bob), 1);

        vm.stopPrank();
    }

    function testAcceptAndMintAll() public {
        vm.deal(bob, 100_000 ether);
        
        vm.startPrank(bob);
            nft.accept("I understand that by holding this NFT I have a duty to cherish it. If I fail to do so, it will perish and it will be my fault.");
            
            for(uint256 i = 0; i<1234; i++) {
                nft.mint{value: 10 * 1.337 ether}();
            }

            assertEq(nft.balanceOf(bob), 1234);

            vm.expectRevert(bytes("Minted out."));
            nft.mint{value: 10 * 1.337 ether}();

            assertEq(nft.totalSupply(), 1234);

        vm.stopPrank();
    }

    function testAcceptAndTransfer() public {
        vm.deal(bob, 1000 ether);
        
        vm.startPrank(bob);
            nft.accept("I understand that by holding this NFT I have a duty to cherish it. If I fail to do so, it will perish and it will be my fault.");
            nft.mint{value: 10 * 1.337 ether}();

            nft.transferFrom(bob, alice,0);

        vm.stopPrank();
    }

    function testNoAcceptMint() public {
        vm.deal(bob, 1000 ether);
        
        vm.startPrank(bob);
            vm.expectRevert(bytes("You need to accept the rules."));
            nft.mint{value: 10 * 1.337 ether}();
        vm.stopPrank();
    }

    function testPix() public {

        vm.deal(bob, 1000 ether);
        
        vm.startPrank(bob);
            nft.accept("I understand that by holding this NFT I have a duty to cherish it. If I fail to do so, it will perish and it will be my fault.");
            nft.mint{value: 10 * 1.337 ether}();

            vm.writeFile("test/output/output.txt",nft.tokenURI(0));
        vm.stopPrank();

    }

    function testPixForward() public {

        vm.deal(bob, 1000 ether);
        
        vm.startPrank(bob);
            nft.accept("I understand that by holding this NFT I have a duty to cherish it. If I fail to do so, it will perish and it will be my fault.");
            nft.mint{value: 10 * 1.337 ether}();

            vm.writeFile("test/output/output.txt",nft.tokenURI(0));

            vm.warp(block.timestamp + 32 days);
            vm.writeFile("test/output/output2.txt",nft.tokenURI(0));

            vm.warp(block.timestamp + 24 days);
            vm.writeFile("test/output/output3.txt",nft.tokenURI(0));
        vm.stopPrank();

    }


}