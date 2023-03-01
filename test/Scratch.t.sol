// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";


contract ScratchTest is Test {

    function setUp() public {

    }

    function testNumber() public {
        emit log_bytes32(keccak256(abi.encodePacked("test")));
        emit log_bytes32(keccak256(abi.encodePacked("test2")));
    }

    function testCrcTable() public {
        uint256[256] memory crcTable = calcCrcTable();

        string memory output;

        /*
        for(uint256 i = 0; i<256; ++i) {
            output = string.concat(output, ",", vm.toString(crcTable[i]));
        }

        vm.writeFile("test/output/crc.txt",output);
        */
    }

    function calcCrcTable() internal pure returns (uint256[256] memory crcTable) {
        uint256 c;

        unchecked{
            for(uint256 n = 0; n < 256; n++) {
                c = n;
                for (uint256 k = 0; k < 8; k++) {
                    if(c & 1 == 1) {
                        c = 0xedb88320 ^ (c >>1);
                    } else {
                        c = c >> 1;
                    }
                }
                crcTable[n] = c;
            }
        }
    }

}

