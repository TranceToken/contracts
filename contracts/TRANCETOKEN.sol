// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./MerkleProof.sol";
import "./Math.sol";
import "./ERC20.sol";
import "./IERC165.sol";
import "./ABDKMath64x64.sol";
import "./IStakingToken.sol";
import "./IRankedMintingToken.sol";
import "./IBurnableToken.sol";
import "./IBurnRedeemable.sol";

contract TRANCECrypto is Context, IRankedMintingToken, IStakingToken, IBurnableToken, ERC20("TRANCE Crypto", "TRANCE") {
    using Math for uint256;
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;


    mapping(uint256 => uint256) private claimedBitMap;

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }
    

    // INTERNAL TYPE TO DESCRIBE A TRANCE MINT INFO
    struct MintInfo {
        address user;
        uint256 amount;
    }

    // INTERNAL TYPE TO DESCRIBE A TRANCE STAKE
    struct StakeInfo {
        uint256 term;
        uint256 maturityTs;
        uint256 amount;
        uint256 apy;
    }
    // EVENTS

     event Claimed(uint256 index, address account, uint256 amount);

    // PUBLIC CONSTANTS
   
    uint256 public constant SECONDS_IN_DAY = 3_600 * 24;
    uint256 public constant DAYS_IN_YEAR = 365;

    uint256 public constant MIN_TERM = 1 * SECONDS_IN_DAY - 1;
    uint256 public constant MAX_TERM_START = 100 * SECONDS_IN_DAY;
    uint256 public constant MAX_TERM_END = 1_000 * SECONDS_IN_DAY;

    uint256 public constant TRANCE_MIN_STAKE = 0;

    uint256 public constant TRANCE_MIN_BURN = 0;

    uint256 public constant TRANCE_APY_START = 20;
    uint256 public constant TRANCE_APY_DAYS_STEP = 365;
    uint256 public constant TRANCE_APY_END = 15;
/* 
    string public constant AUTHORS = "@MrJackLevin @lbelyaev faircrypto.org";
 */
    // PUBLIC STATE, READABLE VIA NAMESAKE GETTERS
    bytes32 public immutable merkleRoot;
    uint256 public immutable genesisTs;
    uint256 public activeMinters;
    uint256 public activeStakes;
    uint256 public totalTRANCEStaked;
    // user address => TRANCE mint info
    mapping(address => MintInfo) public userMints;
    // user address => TRANCE stake info
    mapping(address => StakeInfo) public userStakes;
    // user address => TRANCE burn amount
    mapping(address => uint256) public userBurns;

    // CONSTRUCTOR
    constructor(bytes32 merkleRoot_) {
        genesisTs = block.timestamp;
        merkleRoot = merkleRoot_;
    }

    /**
     * @dev Apply Silly Whale adjustment
     * @param rawPulse Raw Pulse address balance in smallest increment
     * @return Adjusted Pulse address balance in smallest increment
     */
    function _adjustSillyWhale(uint256 rawPulse)
        public
        pure
        returns (uint256)
    {
        if (rawPulse < 50000000e18) {
            /*  For < 50,000,000 PULSE: no penalty :D */
            return rawPulse;
        }
        if (rawPulse >= 50000000e18) {
            /* For >= 50,000,000 PULSE: Pulse Sacrafice diveded by 500 >;) */
            return rawPulse / 500;
        }
        if (rawPulse >= 100000000e18) {
            /* For >= 100,000,000 PULSE: Pulse Sacrafice divided by 1000 >;) */
            return rawPulse / 1000;
        }
        return rawPulse;
    }

    /**
     * @dev cleans up User Mint storage (gets some Gas credit;))
     */
    function _cleanUpUserMint() private {
        delete userMints[_msgSender()];
        activeMinters--;
    }

    /**
     * @dev calculates TRANCE Stake Reward
     */
    function _calculateStakeReward(
        uint256 amount,
        uint256 term,
        uint256 maturityTs,
        uint256 apy
    ) private view returns (uint256) {
        if (block.timestamp > maturityTs) {
            uint256 rate = (apy * term * 1_000_000) / DAYS_IN_YEAR;
            return (amount * rate) / 100_000_000;
        }
        return 0;
    }

    /**
     * @dev calculates APY (in %)
     */
    function _calculateAPY() private view returns (uint256) {
        uint256 decrease = (block.timestamp - genesisTs) / (SECONDS_IN_DAY * TRANCE_APY_DAYS_STEP);
        if (TRANCE_APY_START - TRANCE_APY_END < decrease) return TRANCE_APY_END;
        return TRANCE_APY_START - decrease;
    }

    /**
     * @dev creates User Stake
     */
    function _createStake(uint256 amount, uint256 term) private {
        userStakes[_msgSender()] = StakeInfo({
            term: term,
            maturityTs: block.timestamp + term * SECONDS_IN_DAY,
            amount: amount,
            apy: _calculateAPY()
        });
        activeStakes++;
        totalTRANCEStaked += amount;
    }

    // PUBLIC CONVENIENCE GETTERS


    /**
     * @dev returns User Mint object associated with User account address
     */
    function getUserMint() external view returns (MintInfo memory) {
        return userMints[_msgSender()];
    }

    /**
     * @dev returns TRANCE Stake object associated with User account address
     */
    function getUserStake() external view returns (StakeInfo memory) {
        return userStakes[_msgSender()];
    }

    /**
     * @dev returns current APY
     */
    function getCurrentAPY() external view returns (uint256) {
        return _calculateAPY();
    }

    // PUBLIC STATE-CHANGING METHODS

    /**
     * @dev accepts User Claim claim provided all checks pass (incl. no current claim exists)
     */
    function claim(uint256 index, address account, uint256 _amount, bytes32[] calldata merkleProof) external {
        require(account == msg.sender, "Airdrop: Account does not match");
        require(!isClaimed(index), "Airdrop: Drop already claimed.");
           // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, _amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Airdrop: Invalid proof.");
        // Mark it claimed.
        _setClaimed(index);
        uint256 reward = _adjustSillyWhale(_amount);
        // create and store new MintInfo
        MintInfo memory mintInfo = MintInfo({
            user: account,
            amount: reward
        });
        userMints[account] = mintInfo;
        activeMinters++;
        emit Claimed(index, account, reward);
    }

    /**
     * @dev ends minting upon maturity (and within permitted Withdrawal Time Window), gets minted TRANCE
     */
    function claimMintReward() external {
        MintInfo memory mintInfo = userMints[_msgSender()];
        require(mintInfo.amount > 0, "Claim: No mint exists");

        // calculate reward and mint tokens
        uint256 rewardAmount = mintInfo.amount;
        _mint(_msgSender(), rewardAmount);

        _cleanUpUserMint();
        emit MintClaimed(_msgSender(), rewardAmount);
    }

    /**
     * @dev  ends minting upon maturity (and within permitted Withdrawal time Window)
     *       mints TRANCE coins and splits them between User and designated other address
     */
    function claimMintRewardAndShare(address other, uint256 pct) external {
        MintInfo memory mintInfo = userMints[_msgSender()];
        require(other != address(0), "Claim: Cannot share with zero address");
        require(pct > 0, "Claim: Cannot share zero percent");
        require(pct < 101, "Claim: Cannot share 100+ percent");
        require(mintInfo.amount > 0, "Claim: No mint exists");

        // calculate reward
        uint256 rewardAmount = mintInfo.amount;
        uint256 sharedReward = (rewardAmount * pct) / 100;
        uint256 ownReward = rewardAmount - sharedReward;

        // mint reward tokens
        _mint(_msgSender(), ownReward);
        _mint(other, sharedReward);

        _cleanUpUserMint();
        emit MintClaimed(_msgSender(), rewardAmount);
    }

    /**
     * @dev  ends minting upon maturity (and within permitted Withdrawal time Window)
     *       mints TRANCE coins and stakes 'pct' of it for 'term'
     */
    function claimMintRewardAndStake(uint256 pct, uint256 term) external {
        MintInfo memory mintInfo = userMints[_msgSender()];
        // require(pct > 0, "Claim: Cannot share zero percent");
        require(pct < 101, "Claim: Cannot share >100 percent");
        require(mintInfo.amount > 0, "Claim: No mint exists");

        // calculate reward
        uint256 rewardAmount = mintInfo.amount;
        uint256 stakedReward = (rewardAmount * pct) / 100;
        uint256 ownReward = rewardAmount - stakedReward;

        // mint reward tokens part
        _mint(_msgSender(), ownReward);
        _cleanUpUserMint();
        emit MintClaimed(_msgSender(), rewardAmount);

        // nothing to burn since we haven't minted this part yet
        // stake extra tokens part
        require(stakedReward > TRANCE_MIN_STAKE, "TRANCE: Below min stake");
        require(term * SECONDS_IN_DAY > MIN_TERM, "TRANCE: Below min stake term");
        require(term * SECONDS_IN_DAY < MAX_TERM_END + 1, "TRANCE: Above max stake term");
        require(userStakes[_msgSender()].amount == 0, "TRANCE: stake exists");

        _createStake(stakedReward, term);
        emit Staked(_msgSender(), stakedReward, term);
    }

    /**
     * @dev initiates TRANCE Stake in amount for a term (days)
     */
    function stake(uint256 amount, uint256 term) external {
        require(balanceOf(_msgSender()) >= amount, "TRANCE: not enough balance");
        require(amount > TRANCE_MIN_STAKE, "TRANCE: Below min stake");
        require(term * SECONDS_IN_DAY > MIN_TERM, "TRANCE: Below min stake term");
        require(term * SECONDS_IN_DAY < MAX_TERM_END + 1, "TRANCE: Above max stake term");
        require(userStakes[_msgSender()].amount == 0, "TRANCE: stake exists");

        // burn staked TRANCE
        _burn(_msgSender(), amount);
        // create TRANCE Stake
        _createStake(amount, term);
        emit Staked(_msgSender(), amount, term);
    }

    /**
     * @dev ends TRANCE Stake and gets reward if the Stake is mature
     */
    function withdraw() external {
        StakeInfo memory userStake = userStakes[_msgSender()];
        require(userStake.amount > 0, "TRANCE: no stake exists");

        uint256 TRANCEReward = _calculateStakeReward(
            userStake.amount,
            userStake.term,
            userStake.maturityTs,
            userStake.apy
        );
        activeStakes--;
        totalTRANCEStaked -= userStake.amount;

        // mint staked TRANCE (+ reward)
        _mint(_msgSender(), userStake.amount + TRANCEReward);
        emit Withdrawn(_msgSender(), userStake.amount, TRANCEReward);
        delete userStakes[_msgSender()];
    }

    /**
     * @dev burns TRANCE tokens and creates Proof-Of-Burn record to be used by connected DeFi services
     */
    function burn(address user, uint256 amount) public {
        require(amount > TRANCE_MIN_BURN, "Burn: Below min limit");
        require(
            IERC165(_msgSender()).supportsInterface(type(IBurnRedeemable).interfaceId),
            "Burn: not a supported contract"
        );

        _spendAllowance(user, _msgSender(), amount);
        _burn(user, amount);
        userBurns[user] += amount;
        IBurnRedeemable(_msgSender()).onTokenBurned(user, amount);
    }
}