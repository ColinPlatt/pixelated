// SPDX-License-Identifier: The Unlicense
pragma solidity 0.8.17;

import 'openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import 'openzeppelin-contracts/contracts/access/Ownable.sol';

import './lib/pix.sol';
import './lib/json.sol';

// turnstile address: 0xEcf044C5B4b867CFda001101c617eCd347095B44
interface ITurnstile {
    function register(address) external returns(uint256);
}

contract Pixelated is ERC721Enumerable, Ownable {

    uint16  public constant MAX_SUPPLY          = 1_234;
    uint256 public constant REPLENISH_AMOUNT    = 1.337 ether;

    bytes32 public immutable acceptance;

    struct PIXEL_DATA {
        bytes32 ring_colors;
        uint8   lostPixels;
        uint8   colormap_idx;
        uint64  nextReplenishment;
    }

    mapping(uint256 => PIXEL_DATA) public pixels_data;

    mapping(address => bool) public hasAccepted;

    bytes32[8] public colorMaps = [
        bytes32(0x026736ef8439ebcf8e7b8006bf8cb7482ced84d71b900407a9ed63e1b7bfe234),
        bytes32(0xf2e92189cb6903b98d854cd74ece6c3fafdb2d3472828a950633fdaa52e05032),
        bytes32(0x87970b686eb726750ec792d49da173387a567764d691294d764e53439359c436),
        bytes32(0xc1806ea961848ac00c1f20aa0611529da522a7bd125a3036fe4641b07ee5c61c),
        bytes32(0xdc1cecffc00e2f3196daaf53c27e53e6052a86dc875adb91607824d62469b2bf),
        bytes32(0xaa6277ab923279cf59d78b9b5b7fb5089c90802c353489571fca3c138056fb1b),
        bytes32(0x3be719b0c342797212c4cb33fde865ed9cbe486eb67176265bc0869b54dee925),
        bytes32(0xaa84b30df806b46f859a413cb036bc91466307aec5903fc4635c00a421f25d5c) 
    ];

    string[8] public colorMapsNames = [
        'jet',
        'autumn',
        'summer',
        'spring',
        'winter',
        'terrain',
        'gist_stern',
        'bone'
    ];

    constructor() ERC721("Pixelated", "32768"){
        if(block.chainid == 7700) ITurnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44).register(msg.sender);
        acceptance = keccak256(bytes("I understand that by holding this NFT I have a duty to cherish it. If I fail to do so, it will perish and it will be my fault."));
        
    }

    function accept(string calldata terms) public {
        require(keccak256(bytes(terms)) == acceptance, "Check the terms.");

        hasAccepted[msg.sender] = true;
    }

    function replenish() public payable {
        uint256 userBal = balanceOf(msg.sender);

        require(msg.value >= REPLENISH_AMOUNT*userBal);

        _safeTransfer(msg.value);

        uint256 extension = (msg.value/userBal/86400);

        unchecked{
            for(uint256 i = 0; i<userBal; ++i) {
                if(block.timestamp < pixels_data[tokenOfOwnerByIndex(msg.sender,i)].nextReplenishment) {
                    pixels_data[tokenOfOwnerByIndex(msg.sender,i)].nextReplenishment = uint64(block.timestamp + extension);
                } else {
                    uint8 lostPix = _calcLostPixels(pixels_data[tokenOfOwnerByIndex(msg.sender,i)].nextReplenishment, pixels_data[tokenOfOwnerByIndex(msg.sender,i)].lostPixels);
                    if(lostPix < 64) {
                        pixels_data[tokenOfOwnerByIndex(msg.sender,i)].lostPixels = lostPix;
                        pixels_data[tokenOfOwnerByIndex(msg.sender,i)].nextReplenishment = uint64(block.timestamp + extension);
                    }
                }
            }
        }
    }

    function replenish(uint256 id) public payable {
        require(msg.value >= REPLENISH_AMOUNT);

        _safeTransfer(msg.value);

        if(block.timestamp < pixels_data[id].nextReplenishment) {
            pixels_data[id].nextReplenishment = uint64(block.timestamp + (msg.value/86400));
        } else {
            uint8 lostPix = _calcLostPixels(pixels_data[id].nextReplenishment, pixels_data[id].lostPixels);
            if(lostPix < 64) {
                pixels_data[id].lostPixels = lostPix;
                pixels_data[id].nextReplenishment = uint64(block.timestamp + (msg.value/86400));
            }
            
        }
    }

    function revive(uint256 id) external payable {
        require(msg.value >= ((block.timestamp - pixels_data[id].nextReplenishment)/86400)* 10 * REPLENISH_AMOUNT);
        require(msg.sender == ownerOf(id));

        _safeTransfer(msg.value);

        pixels_data[id].nextReplenishment = uint64(block.timestamp + 1 days);
        pixels_data[id].lostPixels = 0;

    }

    function mint() public payable {
        require(hasAccepted[msg.sender], "You need to accept the rules.");
        require(msg.value >= REPLENISH_AMOUNT*10, "Insufficient Amount.");
        uint256 id = totalSupply();
        require(id < MAX_SUPPLY, "Minted out.");

        _safeTransfer(msg.value);

        _mint(msg.sender, id);
        pixels_data[id] = PIXEL_DATA({
            ring_colors: keccak256(abi.encodePacked(block.difficulty, block.coinbase)),
            lostPixels: 0,
            colormap_idx: uint8(uint256(keccak256(abi.encodePacked(block.timestamp, id))) % 8),
            nextReplenishment: uint64(block.timestamp + 1 days)
        });

    }

    function _calcLostPixels(uint64 _nextReplenishment, uint8 _lostPixels) internal view returns (uint8 lostPix) {
        lostPix = block.timestamp < _nextReplenishment ? _lostPixels : uint8((block.timestamp - _nextReplenishment)/86400 + _lostPixels);

        // do a check in case too many days have passed; 
        lostPix = lostPix > 64 ? 64 : lostPix;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);

        PIXEL_DATA memory imgData = pixels_data[tokenId];

        uint8 lostPix = _calcLostPixels(imgData.nextReplenishment, imgData.lostPixels);

        string memory encodedPng = pix.generateImage(imgData.ring_colors, colorMaps[imgData.colormap_idx], lostPix);

        return json.formattedMetadata(
            string.concat(
                'pixelated #',
                json.toString(tokenId)
            ),
            "pixelated is an experimental NFT project that generates 1234 unique living image files that exist only on the Canto blockchain. Owners must accept the terms to mint or receive the NFT and must continue to replenish the the image or it will perish.",
            encodedPng,
            tokenAttributes(imgData.colormap_idx, lostPix, imgData.nextReplenishment)
        );


    }

    function tokenAttributes(uint8 colorMapIdx, uint8 lostPix, uint64 nextReplenishment) internal view returns (string memory) {

        // we attach the name of the colormap, and colour palette to the ERC721 JSON
        return string.concat(
            json._attr('profile', colorMapsNames[colorMapIdx]),
            json._attr('lost pixels', json.toString(lostPix)),
            json._attr('color map', json.toString(nextReplenishment))
        );

    }

    // @todo make sure that this doesn't mess up the enumeration
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override (ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        if(block.timestamp > pixels_data[firstTokenId].nextReplenishment) {
            if(pixels_data[firstTokenId].lostPixels < 64) pixels_data[firstTokenId].lostPixels++;
        }
    }

    function _safeTransfer(uint256 amount) internal {
        bool success;
        address to = owner();

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }
}
