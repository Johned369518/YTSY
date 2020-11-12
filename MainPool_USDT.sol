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
interface Iregistered {
    function isRegistered(address _user) external view returns(bool);
    function get_members(address _user) external view returns(address[] memory);
    function get_referrer(address _user) external  view returns(address);
}


contract theGame is Ownable{
    using SafeMath for uint256;  
    
    Iregistered REGISTERED_addr;
    address USDT_addr;
    uint256 game_start_time;
    uint256 DAY_REWARD = 3;
    uint256 last_updateday;
    uint256 public dev_reward;   
    uint256 diamondPerNum;
    uint256 goldDiamondPerNum;
    uint256 deposites_num;
    mapping(address => uint256) depositId;
    mapping(uint256 => address) idToUser;
    

    struct pool{
        uint256 pool_balance;
        uint256 champion_pool;
        uint256 Diamond_pool;
        uint256 goldDiamond_pool;
        uint256 safe_pool;
        
        address[4] champion; 
        uint256 day_deposit;
        uint256 Diamond_totalNum;
        uint256 goldDiamond_totalNum;
        uint256 Countdown;
    }

    struct user{
        uint256 direct_deposit;
        uint256 last_deposit;
        uint256 deposit_again;
        uint256 day_performance;
        uint256 total_performance;
        uint256 Diamond_num;
        uint256 glodDiamond_num;
        uint256 total_withdrawal;
        uint256 deposit_base;
    }
  
    mapping(address => user) public users;
    mapping(address => user_internel) users_internel;
    mapping(address => user_reward)  public users_reward;
    mapping(address => mapping(address => uint256)) public members_performance;
    pool public thePool;
 
    constructor(address _registered, address _USDT, address _lockedTransfer) public {
        REGISTERED_addr = Iregistered(_registered);
        USDT_addr = _USDT;
        game_start_time = now;
    }

    function deposit(uint256 _value) external {
        require(REGISTERED_addr.isRegistered(msg.sender),"user not registered!");
        if (users[msg.sender].last_deposit == 0){
            require(_value >= deposite_value,"50USDT Starting vote!");
            users_internel[msg.sender].last_getreward = now;
        }
        else{
            require(_value >= users[msg.sender].last_deposit.add(DEPOSIT_SPACING),"invaild deposit_value!");
        }
        
        if(today() > last_updateday){
            _update_days();
        }

        thePool.Countdown = now;
        deposites_num++;
        depositId[msg.sender] = deposites_num;
        idToUser[deposites_num] = msg.sender;
        

        send_day_reward(msg.sender);
        users[msg.sender].direct_deposit = users[msg.sender].direct_deposit.add(_value);
        users[msg.sender].deposit_base = users[msg.sender].deposit_base.add(_value);
        users[msg.sender].last_deposit = _value;
        

        _update_reffers(msg.sender, _value);
        _send_deposit_reward(msg.sender, _value);
    }

    function get_dayReward(address _user) public view returns(uint256){
        uint256 _base = users[_user].deposit_base;
        uint256 _reward = _base.mul(now.sub(users_internel[_user].last_getreward)).mul(DAY_REWARD).div(1000).div(86400);
        _reward = _stop_reward(_user, _reward);
        
        return _reward;
    }

    function get_champion() public view returns(address _one, address _two, address _three, address _four){
        _one = thePool.champion[0];
        _two = thePool.champion[1];
        _three = thePool.champion[2];
        _four = thePool.champion[3];
    }

    function get_gold_diamond(address _user) public view returns(uint256){
        if(users[_user].total_performance >= 3000000*DECIMALS){
            address[] memory _reffers = REGISTERED_addr.get_members(_user);
            uint256 max;
        
            for (uint256 i = 0; i < _reffers.length; i++){
                if (max < members_performance[_user][_reffers[i]]){
                    max = members_performance[_user][_reffers[i]];
                }
            }
            
            uint256 x = max.div(1000000*DECIMALS);
            uint256 y = (users[_user].total_performance.sub(max)).div(2000000*DECIMALS);
            
            return x > y ? y:x;
        }
    }

    function update_goldDiamond(address _user) public {
        uint256 _x = get_gold_diamond(_user);    
        if (_x > users[_user].glodDiamond_num){
            thePool.goldDiamond_totalNum = thePool.goldDiamond_totalNum.add(_x.sub(users[_user].glodDiamond_num));
            users[_user].glodDiamond_num = _x;
        }
    }

    function get_golddiamondReward(address _user) external {
        require(users[_user].glodDiamond_num != 0,"dont have gold reward!");
        require(users_internel[_user].goldDiamond_lastSend < today(),"today has send!");
              
        uint256 _reward = goldDiamondPerNum.mul(users[_user].glodDiamond_num);
        
        users_reward[_user].glodDiamond_reward = users_reward[_user].glodDiamond_reward.add(_reward);
        thePool.goldDiamond_pool = thePool.goldDiamond_pool.sub(_reward);
        users_internel[_user].goldDiamond_lastSend = today();
    }
    
    function get_diamond(address _user) public view returns(uint256){
        if(users[_user].total_performance >= 105000*DECIMALS){
            address[] memory _reffers = REGISTERED_addr.get_members(_user);
            uint256 max;
        
            for (uint256 i = 0; i < _reffers.length; i++){
                if (max < members_performance[_user][_reffers[i]]){
                    max = members_performance[_user][_reffers[i]];
                }
            }
            
            uint256 x = max.div(35000*DECIMALS);
            uint256 y = (users[_user].total_performance.sub(max)).div(70000*DECIMALS);
            
            return x > y ? y:x;
        }
    }

    function update_Diamond(address _user) public {
        uint256 _x = get_diamond(_user);
        if (_x > users[_user].Diamond_num){
            thePool.Diamond_totalNum = thePool.Diamond_totalNum.add(_x.sub(users[_user].Diamond_num));
            users[_user].Diamond_num = _x;
        }
    }
    
    function get_diamondReward(address _user) external {
        require(users[_user].Diamond_num != 0,"dont have gold reward!");
        require(users_internel[_user].Diamond_lastSend < today(),"today has send!");
            
        uint256 _reward = diamondPerNum.mul(users[_user].Diamond_num);
        
        users_reward[_user].Diamond_reward = users_reward[_user].Diamond_reward.add(_reward);
        thePool.Diamond_pool = thePool.Diamond_pool.sub(_reward);
        users_internel[_user].Diamond_lastSend = today();
    }

    function send_safePool() external{
        
        require(thePool.pool_balance < MIN_SAFEPOOL_BALANCE && now.sub(thePool.Countdown) >= 2 days,"is not the time!");
        
        for(uint256 k; k < SAFEPOOL_SENDNUM; k++){

            address _user = idToUser[deposites_num];
            if(depositId[_user] == deposites_num){
                uint256 _reward = users[_user].direct_deposit.mul(6);

                if (thePool.safe_pool >= _reward){
                    thePool.safe_pool = thePool.safe_pool.sub(_reward);
                    users_reward[_user].safePool_reward =_reward;
                }
                else{
                    users_reward[_user].safePool_reward = thePool.safe_pool;
                    thePool.safe_pool = 0;
                    return;
                }
                delete depositId[_user];
            }
            delete idToUser[deposites_num];
            deposites_num--;
        }
      
    }
    
    function withdrawal_safeMoney() external {
        uint256 _reward = users_reward[msg.sender].safePool_reward;
        
        require(_reward > 0,"user has no safeMoney!");
        _transfer_usdt(msg.sender,_reward);
    }


    function withdrawal_all() public {
        send_day_reward(msg.sender);
        
        
        uint256 _reward18 = users_reward[msg.sender].deposit_reward.add
                         (users_reward[msg.sender].service_reward).add
                         (users_reward[msg.sender].day_reward).add
                         (users_reward[msg.sender].last_28reward);
                         
        
        uint256 _reward = users_reward[msg.sender].champion_reward.add
                         (users_reward[msg.sender].Diamond_reward).add
                         (users_reward[msg.sender].glodDiamond_reward).add
                         (users_reward[msg.sender].last_reward);
                         
        
        
        require(_reward.add(_reward18) > 0, "user has no reward!");
        
        if(_reward18.add(users_reward[msg.sender].haswithdrawal_reward) > users[msg.sender].deposit_base.add(users[msg.sender].deposit_again).mul(18).div(10)){
            uint256 _more = _reward18.add(users_reward[msg.sender].haswithdrawal_reward).sub(users[msg.sender].deposit_base.add(users[msg.sender].deposit_again).mul(18).div(10));
            users_reward[msg.sender].last_28reward = _more;
            _reward18 = _reward18.sub(_more);
        }
        users_reward[msg.sender].haswithdrawal_reward = users_reward[msg.sender].haswithdrawal_reward.add(_reward18);
        
        _reward = _reward.add(_reward18);
                     
        if (_reward.add(users[msg.sender].total_withdrawal) > users[msg.sender].direct_deposit.mul(10)){
            uint256 _more = _reward.add(users[msg.sender].total_withdrawal).sub(users[msg.sender].direct_deposit.mul(10));
            users_reward[msg.sender].last_reward = _more;
            _reward = _reward.sub(_more);
        }
        
        
        users_reward[msg.sender].deposit_reward = 0;
        users_reward[msg.sender].service_reward = 0;
        users_reward[msg.sender].day_reward = 0;
        users_reward[msg.sender].champion_reward = 0;
        users_reward[msg.sender].Diamond_reward = 0;
        users_reward[msg.sender].glodDiamond_reward = 0;
        users[msg.sender].total_withdrawal = users[msg.sender].total_withdrawal.add(_reward);
        
        _transfer_usdt(msg.sender,_reward);
        
    }

    function update_days() external{
        require(today() > last_updateday, "today is not end!");
        _update_days();
    }
    
    function _update_days() internal {
 
        if(thePool.champion[0] != address(0)){
            users_reward[thePool.champion[0]].champion_reward = users_reward[thePool.champion[0]].champion_reward.add(thePool.champion_pool.mul(4).div(100));
        }
        else{
            thePool.pool_balance = thePool.pool_balance.add(thePool.champion_pool.mul(4).div(100));
        }
        if(thePool.champion[1] != address(0)){
            users_reward[thePool.champion[1]].champion_reward = users_reward[thePool.champion[1]].champion_reward.add(thePool.champion_pool.mul(3).div(100));
        }
        else{
            thePool.pool_balance = thePool.pool_balance.add(thePool.champion_pool.mul(3).div(100));
        }
        if(thePool.champion[2] != address(0)){
            users_reward[thePool.champion[2]].champion_reward = users_reward[thePool.champion[2]].champion_reward.add(thePool.champion_pool.mul(2).div(100));
        }
        else{
            thePool.pool_balance = thePool.pool_balance.add(thePool.champion_pool.mul(2).div(100));
        }
        if(thePool.champion[3] != address(0)){
            users_reward[thePool.champion[3]].champion_reward = users_reward[thePool.champion[3]].champion_reward.add(thePool.champion_pool.mul(1).div(100));
        }
        else{
            thePool.pool_balance = thePool.pool_balance.add(thePool.champion_pool.mul(1).div(100));
        }
        thePool.champion_pool = thePool.champion_pool.sub(thePool.champion_pool.mul(10).div(100));
        delete thePool.champion;
        
        thePool.pool_balance = thePool.pool_balance.add(thePool.Diamond_pool).add(thePool.goldDiamond_pool);
        thePool.Diamond_pool = thePool.day_deposit.mul(5).div(100);
        thePool.goldDiamond_pool = thePool.day_deposit.mul(5).div(100);
        if(thePool.pool_balance > thePool.Diamond_pool.add(thePool.goldDiamond_pool)){
            thePool.pool_balance = thePool.pool_balance.sub(thePool.Diamond_pool).sub(thePool.goldDiamond_pool);
        }
        else{
            thePool.Diamond_pool = 0;
            thePool.goldDiamond_pool = 0;
        }
        if (thePool.Diamond_totalNum > 0){
            diamondPerNum = thePool.Diamond_pool.div(thePool.Diamond_totalNum);
        }
        if (thePool.goldDiamond_totalNum > 0){
            goldDiamondPerNum = thePool.goldDiamond_pool.div(thePool.goldDiamond_totalNum);
        }
        
        thePool.day_deposit = 0;
        last_updateday = today();
        
    }

    function get_deposit_number(address _user) internal view returns(uint256){
        uint256 _num;
        address[] memory _reffers = REGISTERED_addr.get_members(_user);
        
        for(uint256 i = 0; i < _reffers.length; i++){
            if (users[_reffers[i]].direct_deposit > 0){
                _num++;
            }
        }
        return _num;
    }

    function today() public view returns(uint256) {
        if (now.sub(game_start_time) % (1 days) != 0){
            return (now.sub(game_start_time)).div(1 days).add(1);
        }
        return (now.sub(game_start_time)).div(1 days);
        
    }

    function get_championCountdown() public view returns(uint256){
        return (1 days) - (now.sub(game_start_time) % (1 days));
    }
    
    function get_allWaitWithdrawal(address _user) public view returns(uint256){
        uint256 _reward = users_reward[_user].day_reward +
                         (users_reward[_user].deposit_reward) +
                         (users_reward[_user].service_reward) +
                         (users_reward[_user].safePool_reward) +
                         (users_reward[_user].glodDiamond_reward) +
                         (users_reward[_user].champion_reward) +
                         (users_reward[_user].Diamond_reward) +
                         (users_reward[_user].last_reward);
        return _reward;
    }
    
    function get_allCanWithdrawal(address _user) public view returns(uint256) {
        
        uint256 _reward = get_allWaitWithdrawal(_user);
                     
        if (_reward.add(users[_user].total_withdrawal) > users[_user].direct_deposit.mul(10)){
            _reward = users[_user].direct_deposit.mul(10) - users[_user].total_withdrawal;
        }
        return _reward;
    
    }
    
    function get_allHasWithdrawal(address _user) public view returns(uint256){
        return users[_user].total_withdrawal;
    }
    
    function get_base(address _user) public view returns(uint256){
        return users[_user].deposit_base.add(users[_user].deposit_again);
    }


    function get18Reward(address _user) public view returns(uint256){
         uint256 all3Reward = users_reward[_user].day_reward + 
                                users_reward[_user].service_reward + 
                                users_reward[_user].deposit_reward + 
                                users_reward[_user].haswithdrawal_reward +
                                users_reward[_user].last_28reward;
                                
        uint256 the18 = (users[_user].direct_deposit + users[_user].deposit_again).mul(18).div(10);
        
        if (all3Reward > the18){
            return the18.sub(users_reward[_user].haswithdrawal_reward);
        }
        else{
            return all3Reward.sub(users_reward[_user].haswithdrawal_reward);
        }
    }
    
    function get10Reward(address _user) public view returns(uint256){
        uint256 all3Reward = users_reward[_user].day_reward + 
                             users_reward[_user].service_reward + 
                             users_reward[_user].deposit_reward + 
                             users_reward[_user].haswithdrawal_reward +
                             users_reward[_user].last_28reward;
                             
        uint256 the18 = (users[_user].direct_deposit + users[_user].deposit_again).mul(18).div(10);
        
        if (all3Reward > the18){
            return all3Reward.sub(the18);
        }
        else{
            return 0;
        }
    }
}