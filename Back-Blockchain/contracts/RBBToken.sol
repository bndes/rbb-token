pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./RBBRegistry.sol";
import "./SpecificRBBToken.sol";
import "./SpecificRBBTokenRegistry.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract RBBToken is Pausable, Ownable {

//TODO: avaliar se deveria ter um set para modificar esses atributos
    SpecificRBBTokenRegistry tokenRegistry;
    RBBRegistry public registry;


    using SafeMath for uint;

    uint8 public decimals = 2;

    address public responsibleForInvestmentConfirmation;
    address public responsibleForSettlement;


    //specificTokenId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;

    //specificTokenId => (specificHash => amount)
    mapping (uint => mapping (bytes32 => uint)) public balanceRequestedTokens;

    event RBBTokenMintRequested(address specificTokenAddr, bytes32 specificHash, uint idInvestor, 
            uint amount, bytes32 docHash);
    event RBBTokenMint(address specificTokenAddr, bytes32 specificHash, uint amount, bytes32 docHash, string[] data);
    event RBBTokenBurn(address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, 
            uint amount, bytes32 docHash);
    event RBBTokenTransfer (address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, uint toId,
            bytes32 toHash, uint amount, bytes32 docHash, string[] data);
    event RBBTokenRedemptionRequested (address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, 
            uint amount, bytes32 docHash, string[] data);
    event RBBTokenRedemptionSettlement(address specificTokenAddr, bytes32 redemptionTransactionHash, 
            bytes32 docHash, string[] data);

    event ManualIntervention_RoleOrAddress(address account, uint8 eventType);


    constructor (address newRegistryAddr, address newSpecificRBBTokenAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        tokenRegistry = SpecificRBBTokenRegistry(newSpecificRBBTokenAddr);
        decimals = _decimals;
        responsibleForInvestmentConfirmation = msg.sender;
        responsibleForSettlement = msg.sender;

    }

///******************************************************************* */

    function requestMint(bytes32 specificInvestimentHash, uint idInvestor, uint amount, bytes32 docHash) 
        public {
    
        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        address specificTokenAddr = msg.sender;

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);
        
        uint specificTokenId = tokenRegistry.getSpecificRBBTokenId(specificTokenAddr);

        balanceRequestedTokens[specificTokenId][specificInvestimentHash] = 
            balanceRequestedTokens[specificTokenId][specificInvestimentHash].add(amount);
    
        emit RBBTokenMintRequested(specificTokenAddr, specificInvestimentHash, idInvestor, amount, docHash);

    }

    function mint(address specificTokenAddr, uint idInvestor, bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public {

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        require (responsibleForInvestmentConfirmation == msg.sender, 
            "Somente um responsável pela confirmação de investimento pode enviar a transação");

        require(amount>0, "Valor a mintar deve ser maior do que zero");

        (uint specificTokenId, uint businessContractOwnerId) = 
                    tokenRegistry.getSpecificRBBTokenIdAndOwnerId(specificTokenAddr);

        balanceRequestedTokens[specificTokenId][specificHash] 
            = balanceRequestedTokens[specificTokenId][specificHash].sub(amount, "Total de emissão excede valor solicitado");

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);

        //Retorna a conta de mint associada ao hash especifico. 
        bytes32 calcHash = specificToken.getHashToMintedAccount(specificHash);

        rbbBalances[specificTokenId][businessContractOwnerId][calcHash] = 
            rbbBalances[specificTokenId][businessContractOwnerId][calcHash].add(amount);

        specificToken.verifyAndActForMint(idInvestor, specificHash, amount, docHash, data);

        emit RBBTokenMint(specificTokenAddr, specificHash, amount, docHash, data);
    }


    function burnOwnTokenBySpecificTokens (address originalSender, bytes32 hashToBurn, uint amount, 
        bytes32 docHash) public {

        address specificTokenAddr = msg.sender;
        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        (uint specificTokenId, uint businessContractOwnerId) = 
                    tokenRegistry.getSpecificRBBTokenIdAndOwnerId(specificTokenAddr);
        
        _burn(specificTokenAddr, originalSender, businessContractOwnerId, hashToBurn, amount, docHash);

    }


    function burnOwnToken (address specificTokenAddr, bytes32 hashToBurn, uint amount, bytes32 docHash) 
        public {

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        uint idToBurn = registry.getId(msg.sender);

        _burn(specificTokenAddr, msg.sender, idToBurn, hashToBurn, amount, docHash);

    }

    function _burn(address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, 
        uint amount, bytes32 docHash) internal {
        
        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);
//        require(amount>0, "Valor a queimar deve ser maior do que zero");

        uint specificTokenId = tokenRegistry.getSpecificRBBTokenId(specificTokenAddr);

        rbbBalances[specificTokenId][fromId][fromHash] = 
            rbbBalances[specificTokenId][fromId][fromHash].sub(amount, "Total de tokens a serem queimados é maior do que o balance");

        emit RBBTokenBurn(specificTokenAddr, originalSender, fromId, fromHash, amount, docHash);
    }

///******************************************************************* */


    function transfer (address specificTokenAddr, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) public whenNotPaused {

        uint fromId = registry.getId(msg.sender);

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");
        uint specificTokenId = tokenRegistry.getSpecificRBBTokenId(specificTokenAddr);

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);
        specificToken.verifyAndActForTransfer(msg.sender, fromId, fromHash, toId, toHash, amount, docHash, data);

        //altera valores de saldo
        rbbBalances[specificTokenId][fromId][fromHash] =
                rbbBalances[specificTokenId][fromId][fromHash].sub(amount, "Saldo da origem não é suficiente para a transferência");
        rbbBalances[specificTokenId][toId][toHash] = rbbBalances[specificTokenId][toId][toHash].add(amount);

        emit RBBTokenTransfer (specificTokenAddr, msg.sender, fromId, fromHash, toId, toHash, amount, docHash, data);

    }

    function redeem (address specificTokenAddr, bytes32 fromHash, uint amount, 
        bytes32 docHash, string[] memory data) public whenNotPaused  {

            uint fromId = registry.getId(msg.sender);

            tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

            require(registry.isValidatedId(fromId), "Conta solicitante do redeem precisa estar com cadastro validado");
            require(amount>0, "Valor a resgatar deve ser maior do que zero");
    
            SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);
            specificToken.verifyAndActForRedeem(msg.sender, fromId, fromHash, amount, docHash, data);

            emit RBBTokenRedemptionRequested(specificTokenAddr, msg.sender, fromId, fromHash, amount, docHash, data);
            _burn(specificTokenAddr, msg.sender, fromId, fromHash, amount, docHash);
    }

   /**
    * Using this function, the Responsible for Settlement indicates that he has made the FIAT money transfer.
    * @ param redemptionTransactionHash hash of the redeem transaction in which the FIAT money settlement occurred.
    * @ param receiptHash hash that proof the FIAT money transfer
    */ 
    function notifyRedemptionSettlement(address specificTokenAddr, bytes32 redemptionTransactionHash, 
        bytes32 docHash, string[] memory data) public whenNotPaused {

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        require (responsibleForSettlement == msg.sender, 
            "Somente um responsável pela liquidição pode enviar a transação");

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);
        specificToken.verifyAndActForRedemptionSettlement(redemptionTransactionHash, docHash, data);

        emit RBBTokenRedemptionSettlement(specificTokenAddr, redemptionTransactionHash, docHash, data);
    }
    

///******************************************************************* */

    function getDecimals() public view returns (uint8) {
        return decimals;
    }

    function getBndesId() view public returns (uint) {
        uint bndesId = registry.getId(owner());
        return bndesId;
    }

    function setResponsibleForInvestmentConfirmation(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pela confirmação do investimento deve ser do mesmo RBB_ID do contrato");
        responsibleForInvestmentConfirmation = rs;
        emit ManualIntervention_RoleOrAddress(rs, 1);
    }

    function setResponsibleForSettlement(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pela liquidação deve ser da mesmo RBB_ID do contrato");
        responsibleForSettlement = rs;
        emit ManualIntervention_RoleOrAddress(rs, 2);
    }


}