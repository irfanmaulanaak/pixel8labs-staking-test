// Sources flattened with hardhat v2.19.4 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v5.0.1

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File contracts/staking.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.20;

contract StakingContract {
    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    //does it need to have limit and reset it when midnight come?
    uint256 public constant dailyEmission = 1000 ether;
    uint256 public totalStaked;

    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsCompounded(address indexed user, uint256 rewardAmount);

    constructor(address _stakingToken, address _rewardsToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    function remainingRewardToken() public view returns (uint256) {
        return rewardsToken.balanceOf(address(this));
    }

    function updateReward(address account) internal {
        if (account != address(0)) {
            rewards[account] = earned(account);
            lastUpdateTime[account] = block.timestamp;
        }
    }

    function earned(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        return
        // staked token * percentage based on how long they staked divided by daily reward
            stakingBalance[account] *
            (blockTime - lastUpdateTime[account]) *
            dailyEmission /
            86400 / 
            totalStaked;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        totalStaked += amount;
        stakingBalance[msg.sender] += amount;
        updateReward(msg.sender);
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Cannot unstake 0");
        require(stakingBalance[msg.sender] >= amount, "Insufficient staking balance");
        totalStaked -= amount;
        stakingBalance[msg.sender] -= amount;
        updateReward(msg.sender);
        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No reward available");
        rewards[msg.sender] = 0;
        rewardsToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    //this is to reinvest the reward
    function compoundRewards() external {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No reward to compound");
        stakingBalance[msg.sender] += reward;
        totalStaked += reward;
        rewards[msg.sender] = 0;
        emit RewardsCompounded(msg.sender, reward);
        emit Staked(msg.sender, reward);
    }

    function governancePower(address account) public view returns (uint256) {
        return stakingBalance[account] * 2 + stakingToken.balanceOf(account);
    }
}
