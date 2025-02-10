// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IHorizonStakingMain } from "../../../contracts/interfaces/internal/IHorizonStakingMain.sol";
import { ITAPCollector } from "../../../contracts/interfaces/ITAPCollector.sol";
import { IPaymentsCollector } from "../../../contracts/interfaces/IPaymentsCollector.sol";
import { IGraphPayments } from "../../../contracts/interfaces/IGraphPayments.sol";
import { TAPCollector } from "../../../contracts/payments/collectors/TAPCollector.sol";
import { PPMMath } from "../../../contracts/libraries/PPMMath.sol";

import { HorizonStakingSharedTest } from "../../shared/horizon-staking/HorizonStakingShared.t.sol";
import { PaymentsEscrowSharedTest } from "../../shared/payments-escrow/PaymentsEscrowShared.t.sol";

contract TAPCollectorTest is HorizonStakingSharedTest, PaymentsEscrowSharedTest {
    using PPMMath for uint256;

    address signer;
    uint256 signerPrivateKey;

    /*
     * MODIFIERS
     */

    modifier useSigner() {
        uint256 proofDeadline = block.timestamp + 1;
        bytes memory signerProof = _getSignerProof(proofDeadline, signerPrivateKey);
        _authorizeSigner(signer, proofDeadline, signerProof);
        _;
    }

    /*
     * SET UP
     */

    function setUp() public virtual override {
        super.setUp();
        (signer, signerPrivateKey) = makeAddrAndKey("signer");
        vm.label({ account: signer, newLabel: "signer" });
    }

    /*
     * HELPERS
     */

    function _getSignerProof(uint256 _proofDeadline, uint256 _signer) internal returns (bytes memory) {
        (, address msgSender, ) = vm.readCallers();
        bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, address(tapCollector), _proofDeadline, msgSender));
        bytes32 proofToDigest = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signer, proofToDigest);
        return abi.encodePacked(r, s, v);
    }

    /*
     * ACTIONS
     */

    function _authorizeSigner(address _signer, uint256 _proofDeadline, bytes memory _proof) internal {
        (, address msgSender, ) = vm.readCallers();

        vm.expectEmit(address(tapCollector));
        emit ITAPCollector.SignerAuthorized(msgSender, _signer);

        tapCollector.authorizeSigner(_signer, _proofDeadline, _proof);

        (address _payer, uint256 thawEndTimestamp, bool revoked) = tapCollector.authorizedSigners(_signer);
        assertEq(_payer, msgSender);
        assertEq(thawEndTimestamp, 0);
        assertEq(revoked, false);
    }

    function _thawSigner(address _signer) internal {
        (, address msgSender, ) = vm.readCallers();
        uint256 expectedThawEndTimestamp = block.timestamp + revokeSignerThawingPeriod;

        vm.expectEmit(address(tapCollector));
        emit ITAPCollector.SignerThawing(msgSender, _signer, expectedThawEndTimestamp);

        tapCollector.thawSigner(_signer);

        (address _payer, uint256 thawEndTimestamp, bool revoked) = tapCollector.authorizedSigners(_signer);
        assertEq(_payer, msgSender);
        assertEq(thawEndTimestamp, expectedThawEndTimestamp);
        assertEq(revoked, false);
    }

    function _cancelThawSigner(address _signer) internal {
        (, address msgSender, ) = vm.readCallers();

        vm.expectEmit(address(tapCollector));
        emit ITAPCollector.SignerThawCanceled(msgSender, _signer, 0);

        tapCollector.cancelThawSigner(_signer);

        (address _payer, uint256 thawEndTimestamp, bool revoked) = tapCollector.authorizedSigners(_signer);
        assertEq(_payer, msgSender);
        assertEq(thawEndTimestamp, 0);
        assertEq(revoked, false);
    }

    function _revokeAuthorizedSigner(address _signer) internal {
        (, address msgSender, ) = vm.readCallers();

        (address beforePayer, uint256 beforeThawEndTimestamp, ) = tapCollector.authorizedSigners(_signer);

        vm.expectEmit(address(tapCollector));
        emit ITAPCollector.SignerRevoked(msgSender, _signer);

        tapCollector.revokeAuthorizedSigner(_signer);

        (address afterPayer, uint256 afterThawEndTimestamp, bool afterRevoked) = tapCollector.authorizedSigners(
            _signer
        );

        assertEq(beforePayer, afterPayer);
        assertEq(beforeThawEndTimestamp, afterThawEndTimestamp);
        assertEq(afterRevoked, true);
    }

    function _collect(IGraphPayments.PaymentTypes _paymentType, bytes memory _data) internal {
        __collect(_paymentType, _data, 0);
    }

    function _collect(IGraphPayments.PaymentTypes _paymentType, bytes memory _data, uint256 _tokensToCollect) internal {
        __collect(_paymentType, _data, _tokensToCollect);
    }

    function __collect(
        IGraphPayments.PaymentTypes _paymentType,
        bytes memory _data,
        uint256 _tokensToCollect
    ) internal {
        (ITAPCollector.SignedRAV memory signedRAV, ) = abi.decode(
            _data,
            (ITAPCollector.SignedRAV, uint256)
        );
        bytes32 messageHash = tapCollector.encodeRAV(signedRAV.rav);
        address _signer = ECDSA.recover(messageHash, signedRAV.signature);
        (address _payer, , ) = tapCollector.authorizedSigners(_signer);
        uint256 tokensAlreadyCollected = tapCollector.tokensCollected(
            signedRAV.rav.dataService,
            signedRAV.rav.collectionId,
            signedRAV.rav.serviceProvider,
            _payer
        );
        uint256 tokensToCollect = _tokensToCollect == 0
            ? signedRAV.rav.valueAggregate - tokensAlreadyCollected
            : _tokensToCollect;

        vm.expectEmit(address(tapCollector));
        emit IPaymentsCollector.PaymentCollected(
            _paymentType,
            signedRAV.rav.collectionId,
            _payer,
            signedRAV.rav.serviceProvider,
            signedRAV.rav.dataService,
            tokensToCollect
        );
        vm.expectEmit(address(tapCollector));
        emit ITAPCollector.RAVCollected(
            signedRAV.rav.collectionId,
            _payer,
            signedRAV.rav.serviceProvider,
            signedRAV.rav.dataService,
            signedRAV.rav.timestampNs,
            signedRAV.rav.valueAggregate,
            signedRAV.rav.metadata,
            signedRAV.signature
        );
        uint256 tokensCollected = _tokensToCollect == 0
            ? tapCollector.collect(_paymentType, _data)
            : tapCollector.collect(_paymentType, _data, _tokensToCollect);

        uint256 tokensCollectedAfter = tapCollector.tokensCollected(
            signedRAV.rav.dataService,
            signedRAV.rav.collectionId,
            signedRAV.rav.serviceProvider,
            _payer
        );
        assertEq(tokensCollected, tokensToCollect);
        assertEq(
            tokensCollectedAfter,
            _tokensToCollect == 0 ? signedRAV.rav.valueAggregate : tokensAlreadyCollected + _tokensToCollect
        );
    }
}
