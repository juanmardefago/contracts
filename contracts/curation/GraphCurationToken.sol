// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../governance/Governed.sol";

/**
 * @title GraphCurationToken contract
 * @dev This is the implementation of the Curation ERC20 token (GCS).
 *
 * GCS are created for each subgraph deployment curated in the Curation contract.
 * The Curation contract is the owner of GCS tokens and the only one allowed to mint or
 * burn them. GCS tokens are transferrable and their holders can do any action allowed
 * in a standard ERC20 token implementation except for burning them.
 *
 * This contract is meant to be used as the implementation for Minimal Proxy clones for
 * gas-saving purposes.
 */
contract GraphCurationToken is ERC20Upgradeable, Governed {
    using SafeMath for uint256;

    // Bookkeeping for GRT deposits
    mapping(address => uint256) public deposits;

    uint256 public totalDeposited;

    /**
     * @dev Graph Curation Token Contract initializer.
     * @param _owner Address of the contract issuing this token
     */
    function initialize(address _owner) external initializer {
        Governed._initialize(_owner);
        ERC20Upgradeable.__ERC20_init("Graph Curation Share", "GCS");
    }

    /**
     * @dev Mint new tokens.
     * @param _to Address to send the newly minted tokens
     * @param _amount Amount of tokens to mint
     * @param _grtDeposit Amount of GRT deposited to mint the GCS
     */
    function mint(
        address _to,
        uint256 _amount,
        uint256 _grtDeposit
    ) public onlyGovernor {
        _mint(_to, _amount);
        deposits[_to] = deposits[_to].add(_grtDeposit);
        totalDeposited = totalDeposited.add(_grtDeposit);
    }

    /**
     * @dev Burn tokens from an address.
     * @param _account Address from where tokens will be burned
     * @param _amount Amount of tokens to burn
     */
    function burnFrom(address _account, uint256 _amount) public onlyGovernor {
        uint256 delta = getDepositDelta(_account, _amount);
        _burn(_account, _amount);
        deposits[_account] = deposits[_account].sub(delta);
        totalDeposited = totalDeposited.sub(delta);
    }

    /**
     * @dev Transfer tokens from the sender to an address.
     * @param _recipient Address to where tokens will be sent
     * @param _amount Amount of tokens to burn
     */
    function transfer(address _recipient, uint256 _amount) public virtual override returns (bool) {
        uint256 depositDelta = getDepositDelta(msg.sender, _amount);
        _transfer(msg.sender, _recipient, _amount);
        deposits[msg.sender] = deposits[msg.sender].sub(depositDelta);
        deposits[_recipient] = deposits[_recipient].add(depositDelta);
        return true;
    }

    function getDepositDelta(address _account, uint256 _amount) public view returns (uint256) {
        return
            balanceOf(_account) == 0 ? 0 : deposits[_account].mul(_amount).div(balanceOf(_account));
    }
}
