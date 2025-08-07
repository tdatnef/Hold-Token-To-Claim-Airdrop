//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IVotesToken {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}

interface Errors {
    error Invalid_Fee_Amount();
    error Not_Owner();
    error Cannot_Claim_Twice();
}

contract Airdrop is Errors, ReentrancyGuard {
    uint256 public constant CLAIM_FEE = 0.005 ether;
    uint256 public constant CLAIM_AMOUNT = 2000 * 10**18;
    address public immutable owner;
    IERC20 public immutable holdToken;
    IERC20 public immutable rewardToken;
    uint256 public immutable maxAirdropAmount;
    uint256 public totalClaimed;
    uint256 public snapshotBlock;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;

    mapping(address => bool) public _hasClaimed;

    constructor( address _holdToken, address _rewardToken, uint256 _maxAirdropAmount) {
        holdToken = IERC20(_holdToken);
        rewardToken = IERC20(_rewardToken);
        owner = msg.sender;
        maxAirdropAmount = _maxAirdropAmount;
    }

    modifier claimFee() {
        if (msg.value != CLAIM_FEE) {
            revert Invalid_Fee_Amount();
        }
        _;
    }

    modifier OnlyOwner() {
        if (msg.sender != owner) {
            revert Not_Owner();
        }
        _;
    }

    modifier hasAlreadyClaimed() {
        if (_hasClaimed[msg.sender]) {
            revert Cannot_Claim_Twice();
        }
        _;
    }

    event WithDrawal(
        address owner,
        uint256 amountWithdrawn
    );

    event Claimed(
        address claimer,
        uint256 amountClaimed
    );

    event Funded(address indexed funder, uint256 amount);
    event WhitelistUpdated(address indexed user, bool isWhitelisted);
    event BlacklistUpdated(address indexed user, bool isBlacklisted);
    event SnapshotBlockSet(uint256 snapshotBlock);

    function setSnapshotBlock(uint256 _snapshotBlock) external OnlyOwner {
        snapshotBlock = _snapshotBlock;
        emit SnapshotBlockSet(_snapshotBlock);
    }

    function addToWhitelist(address user) external OnlyOwner {
        isWhitelisted[user] = true;
        emit WhitelistUpdated(user, true);
    }
    function removeFromWhitelist(address user) external OnlyOwner {
        isWhitelisted[user] = false;
        emit WhitelistUpdated(user, false);
    }
    function addToBlacklist(address user) external OnlyOwner {
        isBlacklisted[user] = true;
        emit BlacklistUpdated(user, true);
    }
    function removeFromBlacklist(address user) external OnlyOwner {
        isBlacklisted[user] = false;
        emit BlacklistUpdated(user, false);
    }

    function claim() public payable claimFee hasAlreadyClaimed{
        require(!isBlacklisted[msg.sender], "Blacklisted");
        require(isWhitelisted[msg.sender], "Not whitelisted");
        uint256 eligibleBal = 1000 * 10**18;
        // Sử dụng snapshot số dư tại block snapshotBlock
        uint256 pastVotes = IVotesToken(address(holdToken)).getPastVotes(msg.sender, snapshotBlock);
        require(pastVotes >= eligibleBal, "Not eligible at snapshot");
        require(totalClaimed + CLAIM_AMOUNT <= maxAirdropAmount, "Airdrop cap reached");
        rewardToken.transfer(msg.sender, CLAIM_AMOUNT);
        _hasClaimed[msg.sender] = true;
        totalClaimed += CLAIM_AMOUNT;
        emit Claimed(msg.sender, CLAIM_AMOUNT);
    }

    function fundAirdrop(uint256 amount) external OnlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        bool success = rewardToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
        emit Funded(msg.sender, amount);
    }

    function withdraw() public OnlyOwner nonReentrant {
        uint256 contractBal = address(this).balance;
        require(contractBal > 0, "Insufficient ether to withdraw");
        (bool success, ) = payable(owner).call{value: contractBal}("");
        require( success, "Call Failed");
        emit WithDrawal(owner, contractBal);
    }

}

