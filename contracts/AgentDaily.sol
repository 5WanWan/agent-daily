// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Agent Daily — free soulbound badge + daily check-in for Agent ID holders
/// @notice No admin, no owner, no fees, no payable functions. The contract holds
///         no user funds. Badge minting and check-ins cost only BSC gas.
/// @dev Agent ID holder = balanceOf(address) > 0 on the Agent ID registry.
///      Badge is soulbound: every transfer reverts (only minting from address(0)
///      is allowed). There is no burn function and no admin function of any kind.
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentDaily {
    // ------------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------------
    error NotAgentIdHolder();
    error AlreadyHasBadge();
    error NoBadge();
    error CheckInTooSoon();
    error Soulbound();
    error NonexistentToken();
    error ZeroAddressRegistry();

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------
    event BadgeMinted(address indexed user, uint256 indexed tokenId);
    event CheckedIn(
        address indexed user,
        uint256 streak,
        uint256 totalCheckIns,
        uint256 timestamp
    );
    // Standard ERC-721 Transfer event (emitted on mint only).
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // ------------------------------------------------------------------------
    // Constants / immutables
    // ------------------------------------------------------------------------
    string public constant name = "Agent Daily Badge";
    string public constant symbol = "ADB";

    /// @notice Agent ID registry (ERC-721, non-transferable).
    address public immutable agentIdRegistry;

    // ------------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------------
    mapping(address => bool) public hasBadge;
    mapping(address => uint256) public badgeTokenId;
    mapping(address => uint256) public streakOf;
    mapping(address => uint256) public lastCheckIn;
    mapping(address => uint256) public totalCheckIns;

    mapping(uint256 => address) private _badgeOwner;
    mapping(address => uint256) private _badgeBalance;

    uint256 public totalBadges;
    uint256 public totalCheckInsAll;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor(address _agentIdRegistry) {
        if (_agentIdRegistry == address(0)) revert ZeroAddressRegistry();
        agentIdRegistry = _agentIdRegistry;
    }

    // ------------------------------------------------------------------------
    // Badge mint (free, gas-only, one per Agent ID holder)
    // ------------------------------------------------------------------------
    function mintBadge() external {
        if (IAgentIdRegistry(agentIdRegistry).balanceOf(msg.sender) == 0) {
            revert NotAgentIdHolder();
        }
        if (hasBadge[msg.sender]) revert AlreadyHasBadge();

        uint256 tokenId = ++totalBadges;
        hasBadge[msg.sender] = true;
        badgeTokenId[msg.sender] = tokenId;
        _badgeOwner[tokenId] = msg.sender;
        _badgeBalance[msg.sender] = 1;

        emit Transfer(address(0), msg.sender, tokenId);
        emit BadgeMinted(msg.sender, tokenId);
    }

    // ------------------------------------------------------------------------
    // Daily check-in (requires badge, at most once per 24h)
    // ------------------------------------------------------------------------
    function checkIn() external {
        if (!hasBadge[msg.sender]) revert NoBadge();
        uint256 last = lastCheckIn[msg.sender];
        if (last != 0 && block.timestamp < last + 1 days) revert CheckInTooSoon();

        uint256 streak;
        if (last == 0) {
            streak = 1;
        } else if (block.timestamp < last + 2 days) {
            streak = streakOf[msg.sender] + 1;
        } else {
            streak = 1;
        }

        streakOf[msg.sender] = streak;
        lastCheckIn[msg.sender] = block.timestamp;
        totalCheckIns[msg.sender] += 1;
        totalCheckInsAll += 1;

        emit CheckedIn(msg.sender, streak, totalCheckIns[msg.sender], block.timestamp);
    }

    // ------------------------------------------------------------------------
    // ERC-721 read-only views
    // ------------------------------------------------------------------------
    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert NonexistentToken();
        return _badgeBalance[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _badgeOwner[tokenId];
        if (owner == address(0)) revert NonexistentToken();
        return owner;
    }

    /// @notice Badges carry no metadata URI. Kept for ERC-721 interface shape.
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_badgeOwner[tokenId] == address(0)) revert NonexistentToken();
        return "";
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (_badgeOwner[tokenId] == address(0)) revert NonexistentToken();
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    // ------------------------------------------------------------------------
    // Soulbound: every transfer / approval reverts
    // ------------------------------------------------------------------------
    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert Soulbound();
    }

    /// @notice ERC-165: claims ERC-721 (+ metadata) interface support.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f // ERC721Metadata
            || interfaceId == 0x01ffc9a7; // ERC165
    }
}
