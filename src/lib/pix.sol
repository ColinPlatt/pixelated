// SPDX-License-Identifier: The Unlicense
pragma solidity 0.8.17;

import {png} from './png.sol';

import {IColormapRegistry} from 'colormap-registry/src/interfaces/IColormapRegistry.sol';

library pix {

    IColormapRegistry constant COLORMAP_REGISTRY =
        IColormapRegistry(0x0000000012883D1da628e31c0FE52e35DcF95D50);

    uint32 constant xMid = 64;
    uint32 constant yMid = 64; 
    
    function generateImage(bytes32 color, bytes32 colorMap, uint8 lostPix) internal view returns (string memory) {
        
        bytes3[] memory palette = new bytes3[](32);

        uint8 red;
        uint8 green;
        uint8 blue;

        unchecked{
            for(uint256 i = 0; i<32; ++i) {
                (red, green, blue) = COLORMAP_REGISTRY.getValueAsUint8(colorMap, uint8(i*8));
                palette[i] = png.rgbToPalette(red, green, blue);
            }
        }

        bytes memory picture = buildCircleLines(color,lostPix);

        return png.encodedPNG(xMid*2, yMid*2, palette, picture, false);

    }


    function toIndex(uint256 _x, uint256 _y) internal pure returns (uint256 index){
        unchecked{
            index = _y * 129 + _x + 1;
        }
        
    }

    function buildCircleLines(bytes32 colors, uint8 lost) internal pure returns (bytes memory) {

        bytes memory pixelArray = new bytes((xMid*2+1) * yMid*2);

        uint xSym;
        uint ySym;
        uint x = 0;

        unchecked{
            for (uint r = 0; r < 64; ++r) {
                bytes1 pixelColor = bytes1(uint8(colors[r/2])/8);
                uint y = r;
                uint r2 = r*r;
                for (x = xMid - r ; x <= xMid; ++x) {
                    for (y = yMid - r ; y <= yMid; ++y) {
                        uint edge = (x - xMid)*(x - xMid) + (y - yMid)*(y - yMid);
                        if (edge >= (r2)-(64-lost) && edge <= (r2)+(64-lost)) {
                            xSym = xMid - (x - xMid);
                            ySym = yMid - (y - yMid);
                            // (x, y), (x, ySym), (xSym , y), (xSym, ySym) are in the circle
                            if (x >= 0 && y >= 0) {
                                pixelArray[toIndex(x, y)] = pixelColor;
                            }
                            if (x >= 0 && ySym >= 0) {
                                pixelArray[toIndex(x, ySym)] = pixelColor;
                            }
                            if (xSym >= 0 && y >= 0) {
                                pixelArray[toIndex(xSym, y)] = pixelColor;
                            }
                            if (xSym >= 0 && ySym >= 0) {
                                pixelArray[toIndex(xSym, ySym)] = pixelColor;
                            }
                        }
                    }
                }
            }
        }
        return pixelArray;
    }


}