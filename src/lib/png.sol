 // SPDX-License-Identifier: Unlicense
/*
 * @title Onchain PNGs
 * @author Colin Platt
 *
 * @dev PNG encoding tools written in Solidity for producing read-only onchain PNG files.
 */

pragma solidity ^0.8.13;

library png {
    
    struct RGBA {
        bytes1 red;
        bytes1 green;
        bytes1 blue;
    }

    function rgbToPalette(uint8 red, uint8 green, uint8 blue) internal pure returns (bytes3) {
        return bytes3(abi.encodePacked(red, green, blue));
    }

    function rgbToPalette(bytes1 red, bytes1 green, bytes1 blue) internal pure returns (bytes3) {
        return bytes3(abi.encodePacked(red, green, blue));
    }

    function rgbToPalette(RGBA memory _rgb) internal pure returns (bytes3) {
        return bytes3(abi.encodePacked(_rgb.red, _rgb.green, _rgb.blue));
    }

    function calculateBitDepth(uint256 _length) internal pure returns (uint256) {
        if (_length < 3) {
            return 2;
        } else if(_length < 5) {
            return 4;
        } else if(_length < 17) {
            return 16;
        } else {
            return 256;
        }
    }

    function formatPalette(bytes3[] memory _palette, bool _8bit) internal pure returns (bytes memory) {
        require(_palette.length <= 256, "PNG: Palette too large.");

        uint256 depth = _8bit? uint256(256) : calculateBitDepth(_palette.length);
        bytes memory paletteObj;

        unchecked{ 
            for (uint i = 0; i<_palette.length; i++) {
                paletteObj = abi.encodePacked(paletteObj, _palette[i]);
            }

            for (uint i = _palette.length; i<depth-1; i++) {
                paletteObj = abi.encodePacked(paletteObj, bytes3(0x000000));
            }
        }

        return abi.encodePacked(
            uint32(depth*3),
            'PLTE',
            bytes3(0x000000),
            paletteObj
        );
    }

    function _tRNS(uint256 _bitDepth, uint256 _palette) internal pure returns (bytes memory) {

        bytes memory tRNSObj = abi.encodePacked(bytes1(0x00));

        unchecked{ 
            for (uint i = 0; i<_palette; i++) {
                tRNSObj = abi.encodePacked(tRNSObj, bytes1(0xFF));
            }

            for (uint i = _palette; i<_bitDepth-1; i++) {
                tRNSObj = abi.encodePacked(tRNSObj, bytes1(0x00));
            }
        }

        return abi.encodePacked(
            uint32(_bitDepth),
            'tRNS',
            tRNSObj
        );
    }


    function rawPNG(uint32 width, uint32 height, bytes3[] memory palette, bytes memory pixels, bool force8bit) internal pure returns (bytes memory) {

        uint32[256] memory crcTable = getCRCTable();

        // Write PLTE
        bytes memory plte = formatPalette(palette, force8bit);

        // Write IHDR
        bytes21 header = bytes21(abi.encodePacked(
                uint32(13),
                'IHDR',
                width,
                height,
                bytes5(0x0803000000)
            )
        );

        bytes7 deflate = bytes7(
            abi.encodePacked(
                bytes2(0x78DA),
                pixels.length > 65535 ? bytes1(0x00) :  bytes1(0x01),
                png.byte2lsb(uint16(pixels.length)),
                ~png.byte2lsb(uint16(pixels.length))
            )
        );

        bytes memory zlib = abi.encodePacked('IDAT', deflate, pixels, _adler32(pixels));

        return abi.encodePacked(
            bytes8(0x89504E470D0A1A0A),
            header, 
            _CRC(crcTable, abi.encodePacked(header),4),
            plte, 
            _CRC(crcTable, abi.encodePacked(plte),4),
            //tRNS, 
            //_CRC(crcTable, abi.encodePacked(tRNS),4),
            uint32(zlib.length-4),
            zlib,
            _CRC(crcTable, abi.encodePacked(zlib), 0), 
            bytes12(0x0000000049454E44AE426082)
        );

    }

    function encodedPNG(uint32 width, uint32 height, bytes3[] memory palette, bytes memory pixels, bool force8bit) internal pure returns (string memory) {
        return string.concat('data:image/png;base64,', base64encode(rawPNG(width, height, palette, pixels, force8bit)));
    }

    // @dev Does not check out of bounds
    function coordinatesToIndex(uint256 _x, uint256 _y, uint256 _width) internal pure returns (uint256 index) {
            index = _y * (_width + 1) + _x + 1;
	}

    /////////////////////////// 
    /// Checksums

    function _CRC(uint32[256] memory crcTable, bytes memory chunk, uint256 offset) internal pure returns (bytes4) {

        uint256 len = chunk.length;

        uint32 c = uint32(0xffffffff);
        unchecked{
            for(uint256 n = offset; n < len; n++) {
                c = uint32(crcTable[(c^uint8(chunk[n])) & 0xff] ^ (c >> 8));
            }
        }
        return bytes4(c)^0xffffffff;

    }

    
    function _adler32(bytes memory _data) internal pure returns (bytes4) {
        uint32 a = 1;
        uint32 b = 0;

        uint256 _len = _data.length;

        unchecked {
            for (uint256 i = 0; i < _len; i++) {
                a = (a + uint8(_data[i])) % 65521; //may need to convert to uint32
                b = (b + a) % 65521;
            }
        }

        return bytes4((b << 16) | a);

    }

    /////////////////////////// 
    /// Utilities

    function byte2lsb(uint16 _input) internal pure returns (bytes2) {

        return byte2lsb(bytes2(_input));

    }

    function byte2lsb(bytes2 _input) internal pure returns (bytes2) {

        return bytes2(abi.encodePacked(bytes1(_input << 8), bytes1(_input)));

    }

    function _toBuffer(bytes memory _bytes) internal pure returns (bytes1[] memory) {

        uint256 _length = _bytes.length;

        bytes1[] memory byteArray = new bytes1[](_length);
        bytes memory tempBytes;

        unchecked{
            for (uint256 i = 0; i<_length; i++) {
                assembly {
                    // Get a location of some free memory and store it in tempBytes as
                    // Solidity does for memory variables.
                    tempBytes := mload(0x40)

                    // The first word of the slice result is potentially a partial
                    // word read from the original array. To read it, we calculate
                    // the length of that partial word and start copying that many
                    // bytes into the array. The first word we copy will start with
                    // data we don't care about, but the last `lengthmod` bytes will
                    // land at the beginning of the contents of the new array. When
                    // we're done copying, we overwrite the full first word with
                    // the actual length of the slice.
                    let lengthmod := and(1, 31)

                    // The multiplication in the next line is necessary
                    // because when slicing multiples of 32 bytes (lengthmod == 0)
                    // the following copy loop was copying the origin's length
                    // and then ending prematurely not copying everything it should.
                    let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                    let end := add(mc, 1)

                    for {
                        // The multiplication in the next line has the same exact purpose
                        // as the one above.
                        let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), i)
                    } lt(mc, end) {
                        mc := add(mc, 0x20)
                        cc := add(cc, 0x20)
                    } {
                        mstore(mc, mload(cc))
                    }

                    mstore(tempBytes, 1)

                    //update free-memory pointer
                    //allocating the array padded to 32 bytes like the compiler does now
                    mstore(0x40, and(add(mc, 31), not(31)))
                }

                byteArray[i] = bytes1(tempBytes);

            }
        }
        
        return byteArray;
    }

    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function base64encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }

    function getCRCTable() private pure returns (uint32[256] memory CRCTable) {

        CRCTable = [
            0,1996959894,3993919788,2567524794,124634137,1886057615,3915621685,2657392035,249268274,2044508324,3772115230,2547177864,162941995,2125561021,3887607047,2428444049,498536548,1789927666,4089016648,2227061214,450548861,1843258603,4107580753,2211677639,325883990,1684777152,4251122042,2321926636,335633487,1661365465,4195302755,2366115317,997073096,1281953886,3579855332,2724688242,1006888145,1258607687,3524101629,2768942443,901097722,1119000684,3686517206,2898065728,853044451,1172266101,3705015759,2882616665,651767980,1373503546,3369554304,3218104598,565507253,1454621731,3485111705,3099436303,671266974,1594198024,3322730930,2970347812,795835527,1483230225,3244367275,3060149565,1994146192,31158534,2563907772,4023717930,1907459465,112637215,2680153253,3904427059,2013776290,251722036,2517215374,3775830040,2137656763,141376813,2439277719,3865271297,1802195444,476864866,2238001368,4066508878,1812370925,453092731,2181625025,4111451223,1706088902,314042704,2344532202,4240017532,1658658271,366619977,2362670323,4224994405,1303535960,984961486,2747007092,3569037538,1256170817,1037604311,2765210733,3554079995,1131014506,879679996,2909243462,3663771856,1141124467,855842277,2852801631,3708648649,1342533948,654459306,3188396048,3373015174,1466479909,544179635,3110523913,3462522015,1591671054,702138776,2966460450,3352799412,1504918807,783551873,3082640443,3233442989,3988292384,2596254646,62317068,1957810842,3939845945,2647816111,81470997,1943803523,3814918930,2489596804,225274430,2053790376,3826175755,2466906013,167816743,2097651377,4027552580,2265490386,503444072,1762050814,4150417245,2154129355,426522225,1852507879,4275313526,2312317920,282753626,1742555852,4189708143,2394877945,397917763,1622183637,3604390888,2714866558,953729732,1340076626,3518719985,2797360999,1068828381,1219638859,3624741850,2936675148,906185462,1090812512,3747672003,2825379669,829329135,1181335161,3412177804,3160834842,628085408,1382605366,3423369109,3138078467,570562233,1426400815,3317316542,2998733608,733239954,1555261956,3268935591,3050360625,752459403,1541320221,2607071920,3965973030,1969922972,40735498,2617837225,3943577151,1913087877,83908371,2512341634,3803740692,2075208622,213261112,2463272603,3855990285,2094854071,198958881,2262029012,4057260610,1759359992,534414190,2176718541,4139329115,1873836001,414664567,2282248934,4279200368,1711684554,285281116,2405801727,4167216745,1634467795,376229701,2685067896,3608007406,1308918612,956543938,2808555105,3495958263,1231636301,1047427035,2932959818,3654703836,1088359270,936918000,2847714899,3736837829,1202900863,817233897,3183342108,3401237130,1404277552,615818150,3134207493,3453421203,1423857449,601450431,3009837614,3294710456,1567103746,711928724,3020668471,3272380065,1510334235,755167117
        ];
    }

}

