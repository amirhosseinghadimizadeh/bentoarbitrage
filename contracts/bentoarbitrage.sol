// SPDX-License-Identifier: GPLv3
pragma solidity 0.7.1;
import "./IUniswapRouter02.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}
interface IFlashBorrower {
    /// @notice The flashloan callback. `amount` + `fee` needs to repayed to msg.sender before this call returns.
    /// @param sender The address of the invoker of this flashloan.
    /// @param token The address of the token that is loaned.
    /// @param amount of the `token` that is loaned.
    /// @param fee The fee that needs to be paid on top for this loan. Needs to be the same as `token`.
    /// @param data Additional data that was passed to the flashloan function.
    function onFlashLoan(
        address sender,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}
interface BentoBox {
   function flashLoan(
        IFlashBorrower borrower,
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes calldata data)external;
}

contract bentoarbitrage is Ownable{
    uint256 immutable deadline=1000;
    using SafeMath for uint256;
    IUniswapRouter02 public uniRouter;
    IUniswapRouter02 public sushiRouter;
    BentoBox public Provider;
    function Balance(address token)public view returns(uint256){
        return IERC20(token).balanceOf(address(this));    
        
    }
        function Approve(address token,address spender,uint256 value)public  returns(bool){
        return IERC20(token).approve(spender,value);    
        
    }
    function intialize(IUniswapRouter02 _uniRouter,IUniswapRouter02 _sushiRouter,BentoBox _provider)public{
        require(address(uniRouter)==address(0)&&address(sushiRouter)==address(0));
        uniRouter =_uniRouter;
        sushiRouter =_sushiRouter;
        Provider =_provider;
    }
    function ArbitrageFromSushiToUni(address token0,address token1,uint256 amountin)public returns(uint256){
        IERC20(token0).approve(address(sushiRouter),amountin);
        address[] memory sushipath=new address[](2);
        address[] memory unipath=new address[](2);
        uint256 token0before=Balance(token0);
        uint256 token1before=Balance(token1);
        uint256 token0after;
        uint256 token1after;
        uint256 token0amount;
        uint256 token1amount;
        uint256 totalprofit;
        sushipath[0]=token0;
        sushipath[1]=token1;
        unipath[0]=token1;
        unipath[1]=token0;
        Approve(token0,address(sushiRouter),amountin);
        sushiRouter.swapExactTokensForTokens(amountin,0,sushipath,address(this),block.timestamp.add(deadline));
        token1after=Balance(token1);
        token1amount=token1after.sub(token1before);
        Approve(token1,address(uniRouter),token1amount);
        uniRouter.swapExactTokensForTokens(token1amount,0,unipath,address(this),block.timestamp.add(deadline));
        token0after=Balance(token0);
        token0amount=token0after.sub(token0before);
        require(token0amount>amountin,"Revert:ProfitLess Arbitrage");
        totalprofit=token0amount.sub(amountin);
        return totalprofit;
    }
        function ArbitrageFromUniToSushi(address token0,address token1,uint256 amountin)public returns(uint256){
        IERC20(token0).approve(address(sushiRouter),amountin);
        address[] memory unipath=new address[](2);
        address[] memory sushipath=new address[](2);
        uint256 token0before=Balance(token0);
        uint256 token1before=Balance(token1);
        uint256 token0after;
        uint256 token1after;
        uint256 token0amount;
        uint256 token1amount;
        uint256 totalprofit;
        unipath[0]=token0;
        unipath[1]=token1;
        sushipath[0]=token1;
        sushipath[1]=token0;
        Approve(token0,address(uniRouter),amountin);
        uniRouter.swapExactTokensForTokens(amountin,0,unipath,address(this),block.timestamp.add(deadline));
        token1after=Balance(token1);
        token1amount=token1after.sub(token1before);
        Approve(token1,address(sushiRouter),token1amount);
        sushiRouter.swapExactTokensForTokens(token1amount,0,sushipath,address(this),block.timestamp.add(deadline));
        token0after=Balance(token0);
        token0amount=token0after.sub(token0before);
        require(token0amount>amountin,"Revert:ProfitLess Arbitrage");
        totalprofit=token0amount.sub(amountin);
        return totalprofit;
    }
    function StartOperation(IERC20 token,address token1,uint256 amount,bool direction)public{
        bytes memory data =abi.encodePacked(direction,token,token1,amount);
        Provider.flashLoan(IFlashBorrower(address(this)),address(this),token,amount,data);
    }
    function test(IFlashBorrower address1,address address2,IERC20 token,uint256 amount)public {
               Provider.flashLoan(address1,address2,token,amount,""); 
    }
    function onFlashLoan(address sender,IERC20 token,uint256 amount,uint256 fee,bytes calldata data) public{
      (bool direction,address token0,address token1,uint256 _amount)=abi.decode(data,(bool,address,address,uint256));
      uint256 totalprofit=ExecuteArbitrage(direction,token0,token1,_amount);
      uint256 finalprofit=totalprofit.sub(totalprofit,"FlashLoan Fee More Than Profit");
      IERC20(token0).transfer(address(Provider),amount.add(fee));
      IERC20(token0).transfer(tx.origin,finalprofit);
      }
    //direction true=sushitouni false=unitosushi
    function ExecuteArbitrage(bool direction,address token0,address token1,uint256 amount)public returns(uint256){
        return direction == true ?ArbitrageFromSushiToUni(token0,token1,amount):ArbitrageFromUniToSushi(token0,token1,amount);
    }
    function emergencyWithdraw(IERC20 token)public {
        token.transfer(msg.sender,Balance(address(token)));
    }
}
