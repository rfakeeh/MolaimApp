// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC1155Base.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MalaemSukuk is ERC1155Base, Permissions, ContractMetadata {
    struct Project {
        string name;
        string sector;
        string location;
        uint256 fundingRequired;
        uint256 expectedReturn;
        uint256 durationMonths;
        bool exists;
    }

    uint256 public nextProjectId = 1;
    uint256 public nextSukukId = 1;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => uint256) public sukukToProject;
    mapping(uint256 => address) public sukukOwner;

    event ProjectCreated(uint256 indexed projectId, string name);
    event SukukPurchased(uint256 indexed sukukId, address indexed buyer);
    event DividendDistributed(uint256 indexed sukukId, uint256 amount);
    event SukukTransferred(uint256 indexed sukukId, address from, address to);

    constructor(address _defaultAdmin) ERC1155Base("Malaem Sukuk", "SUK") {
        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    function createProject(
        string memory name,
        string memory sector,
        string memory location,
        uint256 fundingRequired,
        uint256 expectedReturn,
        uint256 durationMonths
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        projects[nextProjectId] = Project({
            name: name,
            sector: sector,
            location: location,
            fundingRequired: fundingRequired,
            expectedReturn: expectedReturn,
            durationMonths: durationMonths,
            exists: true
        });

        emit ProjectCreated(nextProjectId, name);
        nextProjectId++;
    }

    function issueSukuk(uint256 projectId, uint256 amount, uint256 pricePerSukuk) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(projects[projectId].exists, "Project does not exist");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = nextSukukId;
            _mint(address(this), tokenId, 1, "");
            sukukToProject[tokenId] = projectId;
            nextSukukId++;
        }
    }

    function buySukuk(uint256 sukukId) external payable {
        require(balanceOf(address(this), sukukId) == 1, "Sukuk not available");
        uint256 price = projects[sukukToProject[sukukId]].fundingRequired / 10; // assume 10 sukuk per project
        require(msg.value >= price, "Insufficient payment");

        _safeTransferFrom(address(this), msg.sender, sukukId, 1, "");
        sukukOwner[sukukId] = msg.sender;
        emit SukukPurchased(sukukId, msg.sender);
    }

    function distributeDividend(uint256 sukukId) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        address owner = sukukOwner[sukukId];
        require(owner != address(0), "No owner");

        payable(owner).transfer(msg.value);
        emit DividendDistributed(sukukId, msg.value);
    }

    function transferSukuk(uint256 sukukId, address to) external {
        require(msg.sender == sukukOwner[sukukId], "Not owner");
        _safeTransferFrom(msg.sender, to, sukukId, 1, "");
        sukukOwner[sukukId] = to;
        emit SukukTransferred(sukukId, msg.sender, to);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
