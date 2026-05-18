// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControlLite } from "../access/AccessControlLite.sol";

contract AssetBadgeNFT is AccessControlLite {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public constant name = "RWA Asset Badge";
    string public constant symbol = "RWAB";
    uint256 public totalSupply;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => string) public tokenURI;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    function mint(address to, string calldata uri)
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 id)
    {
        require(to != address(0), "ZERO_TO");
        id = ++totalSupply;
        ownerOf[id] = to;
        balanceOf[to]++;
        tokenURI[id] = uri;
        emit Transfer(address(0), to, id);
    }

    function approve(address spender, uint256 tokenId) external {
        address owner = ownerOf[tokenId];
        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");
        getApproved[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        address owner = ownerOf[tokenId];
        require(owner == from, "NOT_OWNER");
        require(to != address(0), "ZERO_TO");
        require(
            msg.sender == owner || getApproved[tokenId] == msg.sender
                || isApprovedForAll[owner][msg.sender],
            "NOT_AUTHORIZED"
        );
        delete getApproved[tokenId];
        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }
}
