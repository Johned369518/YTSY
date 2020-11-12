pragma solidity 0.6.0;

contract Ownable{
    address private _owner;
    address private newOwner;

    constructor() public {
        _owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwner(address _newOwner) external onlyOwner{
        newOwner = _newOwner;
    }

    function getOwner() external {
        require(msg.sender == newOwner);
        _owner = newOwner;
    }
}
interface IERC20 {
    function allowance(address owner, address spender) external view returns (uint);
    function transferFrom(address from, address to, uint value) external;
    function approve(address spender, uint value) external;
    function transfer(address to,uint256 value) external;
    function balanceOf(address _addr) external returns(uint256);
    event Approval(address indexed owner, address indexed spender, uint value);
}
library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {    
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Registered is Ownable{
    
    using SafeMath for uint256;

    uint256 constant REGISTERED_VALUE = 30 * DECIMALS;
    uint256 constant DECIMALS = 10 ** 6;
    
    address USDT;
    uint256 userid_num = 1;
    uint256 pool_balance;

    struct user{
        uint256 userid;
        address referrer;
        address[] members;
        uint256 registered_reward;
    }
    
    mapping(address => user)  public users;
    
    constructor(address _USDT,address _fristMan) public {
        USDT = _USDT;
        users[_fristMan].userid = 1;
    }
    
    function registered(address _referrer) external {

        require(users[msg.sender].userid == 0,"user has registered!");
        require(users[_referrer].userid != 0, "invaild referrer!");
     

        IERC20(USDT).transferFrom(msg.sender, address(this), REGISTERED_VALUE);
         

        userid_num++;
        users[msg.sender].userid = userid_num;
        users[msg.sender].referrer = _referrer;

        users[_referrer].members.push(msg.sender);
        

        _sendRegisteredReward(msg.sender);
        
    }
    

    function _sendRegisteredReward(address _user) internal {
        uint256 _reward = REGISTERED_VALUE.div(11);

        for (uint8 i = 0; i < 11; i++){
            address _referrer = users[_user].referrer;
            if(_referrer == address(0)){
                return;
            }
            if (users[_referrer].members.length > i){
                users[_referrer].registered_reward = users[_referrer].registered_reward.add(_reward);
            }
            _user = _referrer;
        }
    }

    function withdrawalReward(address _user) external {
        uint256 _reward = users[_user].registered_reward;
        require(_reward > 0, "user has no reward!");
        IERC20(USDT).transfer(_user, _reward);
        users[_user].registered_reward = 0;
    }
    
    function isRegistered(address _user) external view returns(bool){
        return users[_user].userid != 0;
    }
    function get_members(address _user) external view returns(address[] memory){
        return users[_user].members;
    }
    function get_referrer(address _user) external  view returns(address){
        return users[_user].referrer;
    }
}