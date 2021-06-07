// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Burnable
} from "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import {
    ERC20Snapshot
} from "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import {ERC20Permit} from "@openzeppelin/contracts/drafts/ERC20Permit.sol";
import {TimelockConfig} from "./TimelockConfig.sol";

interface ICustosToken {
    event Advanced(uint256 epoch, uint256 supplyMinted);

    function advance() external;

    function getAdmin() external view returns (address admin);

    function getTreasurer() external view returns (address treasurer);

    function getTimelock() external view returns (uint256 timelock);

    function getInflation() external view returns (uint256 inflation);

    function getEpochDuration() external view returns (uint256 epochDuration);
}

// CustosToken
contract CustosToken is
    ICustosToken,
    ERC20("Custos", "CTOS"),
    ERC20Burnable,
    ERC20Snapshot,
    ERC20Permit("Custos"),
    TimelockConfig
{
    bytes32 public constant INFLATION_CONFIG_ID = keccak256("Inflation");
    bytes32 public constant EPOCH_DURATION_CONFIG_ID =
        keccak256("EpochDuration");
    bytes32 public constant TREASURER_CONFIG_ID = keccak256("Treasurer");

    uint256 private _epoch;
    uint256 private _previousEpochTimestamp;

    constructor(
        address admin,
        address treasurer,
        uint256 inflation,
        uint256 epochDuration,
        uint256 timelock,
        uint256 supply,
        uint256 epochStart
    ) TimelockConfig(admin, timelock) {
        // set config
        TimelockConfig._setRawConfig(TREASURER_CONFIG_ID, uint256(treasurer));
        TimelockConfig._setRawConfig(INFLATION_CONFIG_ID, inflation);
        TimelockConfig._setRawConfig(EPOCH_DURATION_CONFIG_ID, epochDuration);

        // set epoch timestamp
        _previousEpochTimestamp = epochStart;

        // mint initial supply
        ERC20._mint(treasurer, supply);
    }

    function advance() external override {
        // require new epoch
        require(
            block.timestamp >= _previousEpochTimestamp + getEpochDuration(),
            "not ready to advance"
        );
        // set epoch
        _epoch++;
        _previousEpochTimestamp = block.timestamp;
        // create snapshot
        ERC20Snapshot._snapshot();
        // calculate inflation amount
        uint256 supplyMinted = getInflation();

        ERC20._mint(getTreasurer(), supplyMinted);

        // emit event
        emit Advanced(_epoch, supplyMinted);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) {
        ERC20Snapshot._beforeTokenTransfer(from, to, amount);
    }

    function getEpoch() public view returns (uint256 epoch) {
        return _epoch;
    }

    function getAdmin() public view override returns (address admin) {
        return
            address(
                TimelockConfig.getConfig(TimelockConfig.ADMIN_CONFIG_ID).value
            );
    }

    function getTreasurer() public view override returns (address treasurer) {
        return address(TimelockConfig.getConfig(TREASURER_CONFIG_ID).value);
    }

    function getTimelock() public view override returns (uint256 timelock) {
        return
            TimelockConfig.getConfig(TimelockConfig.TIMELOCK_CONFIG_ID).value;
    }

    function getInflation() public view override returns (uint256 inflation) {
        return TimelockConfig.getConfig(INFLATION_CONFIG_ID).value;
    }

    function getEpochDuration()
        public
        view
        override
        returns (uint256 epochDuration)
    {
        return TimelockConfig.getConfig(EPOCH_DURATION_CONFIG_ID).value;
    }
}
