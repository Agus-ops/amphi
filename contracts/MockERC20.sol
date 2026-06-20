// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockERC20 {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event MinterChanged(address indexed minter, bool allowed);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SeedingFinalized();

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => bool) public minters;
    address public owner;
    bool public seedingDone;
    uint256 public maxSeedSupply;

    modifier onlyMinter() { require(minters[msg.sender], "ONLY_MINTER"); _; }
    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }
    modifier canOwnerMint() { require(!seedingDone, "SEEDING_DONE"); _; }

    constructor(string memory _name, string memory _symbol, address _owner, uint256 _maxSeedSupply) {
        require(_owner != address(0), "ZERO_OWNER");
        name = _name;
        symbol = _symbol;
        owner = _owner;
        maxSeedSupply = _maxSeedSupply;
        emit OwnershipTransferred(address(0), _owner);
    }

    function ownerMint(address to, uint256 amount) external onlyOwner canOwnerMint {
        require(to != address(0), "ZERO_ADDR");
        require(totalSupply + amount <= maxSeedSupply, "EXCEEDS_MAX_SEED");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function finalizeSeeding() external onlyOwner {
        seedingDone = true;
        emit SeedingFinalized();
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "ZERO_ADDR");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function setMinter(address minter, bool allowed) external onlyOwner {
        minters[minter] = allowed;
        emit MinterChanged(minter, allowed);
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "ZERO_ADDR");
        require(balanceOf[msg.sender] >= amount, "BALANCE");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(to != address(0), "ZERO_ADDR");
        require(balanceOf[from] >= amount, "BALANCE");
        require(allowance[from][msg.sender] >= amount, "ALLOW");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
