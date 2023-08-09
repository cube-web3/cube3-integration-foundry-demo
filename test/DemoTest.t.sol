// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DemoIntegrationERC721} from "../src/DemoIntegrationERC721.sol";
import {DemoIntegrationERC721Upgradeable} from "../src/DemoIntegrationERC721Upgradeable.sol";
import {Cube3ProtocolTestUtils} from "cube3/test/foundry/utils/deploy.sol";


contract DemoTest is Cube3ProtocolTestUtils {

    DemoIntegrationERC721 internal demo;

    ERC1967Proxy internal demoProxy;
    DemoIntegrationERC721Upgradeable internal demoUpgradeable;
    DemoIntegrationERC721Upgradeable internal wrappedDemoProxy;

    address internal integrationSecurityAdmin = makeAddr("integrationSecurityAdmin");

    function setUp() public {
        // You MUST deploy the mock CUBE3 protocol contracts before running the tests
        _deployMockCube3Protocol();

        vm.startPrank(integrationSecurityAdmin);

        // deploy the standalone demo integration, where the security admin is implictly the deployer
        demo = new DemoIntegrationERC721();

        // deploy the upgradeable integration implementation
        demoUpgradeable = new DemoIntegrationERC721Upgradeable();

        // deploy the proxy and set the security admin address explicityl
        demoProxy = new ERC1967Proxy(
            address(demoUpgradeable),
            abi.encodeCall(DemoIntegrationERC721Upgradeable.initialize, (integrationSecurityAdmin))
        );

        vm.stopPrank();

        // wrap the proxy in the implementation's interface for convenience
        wrappedDemoProxy = DemoIntegrationERC721Upgradeable(address(demoProxy));
    }


    function testStandalone() public {

        // Register the the integration with the CUBE3 protocol.
        bytes4[] memory enabledByDefaultFnSelectors = new bytes4[](1);
        enabledByDefaultFnSelectors[0] = demo.safeMint.selector;

        vm.startPrank(integrationSecurityAdmin);

        // Under normal circumstances, the registrar signature would be provided off-chain by the CUBE3 platform.
        // The mock protocol allows use an empty signature generated on-chain for testing purposes.
        bytes memory registrarSignature = new bytes(65);
        demo.registerIntegrationWithCube3(registrarSignature, enabledByDefaultFnSelectors);

        vm.stopPrank();

        // The `cube3SecurePayload` parameter is required for all functions that are protected by the `cube3Protected` modifier.
        // The payload is generated off-chain by the CUBE3 platform and provided to the EOA executing the TX.
        // For the purposes of testing, we can just pass an empty bytes array, with minimum length of 64 bytes, as the payload to mimic
        // the protocol's behaviour.
        bytes memory cube3SecurePayload = new bytes(64);
        
        // call the mint function as the end-user
        address user = makeAddr("user");
        vm.startPrank(user);
        demo.safeMint(1, cube3SecurePayload);
    }

    function testUpgradeable() public {

        // Register the the integration with the CUBE3 protocol.
        bytes4[] memory enabledByDefaultFnSelectors = new bytes4[](1);
        enabledByDefaultFnSelectors[0] = wrappedDemoProxy.safeMint.selector;

        vm.startPrank(integrationSecurityAdmin);

        // Under normal circumstances, the registrar signature would be provided off-chain by the CUBE3 platform.
        // The mock protocol allows use an empty signature generated on-chain for testing purposes.
        // Unlike the standalone, the upgradeable integration stores its function-level protection in the GateKeeper contract.
        bytes memory registrarSignature = new bytes(65);
        wrappedDemoProxy.registerIntegrationWithCube3(registrarSignature, enabledByDefaultFnSelectors);

        vm.stopPrank();
    }
}