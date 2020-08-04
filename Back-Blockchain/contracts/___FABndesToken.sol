pragma solidity ^0.5.0;

import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract FABndesToken is Ownable, Pausable {

    using SafeMath for uint;

    RBBRegistry public registry;

    uint8 public decimals = 2;

    //clientId => (financialContract => amount)
    mapping (uint => mapping (uint => uint)) public clientIdFCAmount;
    
    //supplier => amount
    mapping (uint => uint) public supplierAmount;

    //É o id, nao tem como especializar dentro do BNDES. Diferença no front-end
    uint public responsibleForSettlement;
    uint public responsibleForDisbursement;

    /*
    TODO: avaliar o que precisaria ir para o framework de mudanca. Atualizaçao do registry e responsaveis
    precisaria passar por uma mudanca? Para formalismo?
    Nesse caso, setResposible apenas pelo framework?

    Atualizacao dos saldos precisaria para evitar migracao de dados em caso de regras e para formalismo
    
    Avaliar se incluiremos regras de tratamento de erros aqui ou pelo framework de governanca

    */

    //ATENCAO: troquei cnpj por id no argumento do evento e tirei arg de contrato no resgate - impacto no BNDESTransparente
    event Disbursement  (uint idClient, uint amount, uint idFinancialSupportAgreement);
    event TokenTransfer (uint fromCnpj, uint fromIdFinancialSupportAgreement, uint toCnpj, uint amount);
    event RedemptionRequested (uint idClaimer, uint amount);
    event RedemptionSettlement(string redemptionTransactionHash, string  receiptHash);

    event ManualInterventionClient_MintAndBurn(uint idClient, uint idFinancialSupportAgreement, uint256 amount, string description, uint8 eventType);


    constructor (address newRegistryAddr, uint8 _decimals, uint responsibleForDisbursementArg, uint responsibleForSettlementArg)
    public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
        setResponsibleForDisbursement(responsibleForDisbursementArg);
        setResponsibleForSettlement(responsibleForSettlementArg);
    }

    function makeDisbursement(uint clientId, uint idFinancialSupportAgreement, uint amount)
        public onlyResponsibleForDisbursement {

        require(registry.isValidatedId(clientId), "Cliente precisa estar com conta blockchain validada");

        //incluir regras especificas de validacao de cliente e do contrato aqui
        //****** */

        //altera valores de saldo
        clientIdFCAmount[clientId][idFinancialSupportAgreement] =
            clientIdFCAmount[clientId][idFinancialSupportAgreement].add(amount);

        emit Disbursement (clientId, amount, idFinancialSupportAgreement);

    }

    function paySupplier (uint idFinancialSupportAgreement, uint amount, uint supplierId) public {
        
        uint clientId = registry.getId(msg.sender);
        require(registry.isValidatedId(clientId), "Cliente precisa estar com conta blockchain validada");
        require(registry.isValidatedId(supplierId), "Fornecedor precisa estar conta blockchain validada");

        require(clientId != supplierId,
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        //incluir regras especificas de pagamento aqui
        //****** */

        //altera valores de saldo
        clientIdFCAmount[clientId][idFinancialSupportAgreement] = 
            clientIdFCAmount[clientId][idFinancialSupportAgreement].sub(amount, "Saldo do cliente não é suficiente");
        supplierAmount[supplierId] = supplierAmount[supplierId].add(amount);

        emit TokenTransfer (clientId, idFinancialSupportAgreement, supplierId, amount);
    }

    function redeem(uint amount) public {
        
        uint supplierId = registry.getId(msg.sender);
        require(registry.isValidatedId(supplierId), "Fornecedor precisa estar conta blockchain validada");


        //incluir regras especificas de resgate aqui
        //****** */
        
        //altera valores de saldo
        supplierAmount[supplierId] = supplierAmount[supplierId].sub(amount, "saldo não é suficiente");

        //TODO: chama metodo para pagamento FIAT (mock?)
        //****** */

        emit RedemptionRequested (supplierId, amount);

    }

   /**
    * Using this function, the Responsible for Settlement indicates that he has made the FIAT money transfer.
    * @param redemptionTransactionHash hash of the redeem transaction in which the FIAT money settlement occurred.
    * @param receiptHash hash that proof the FIAT money transfer
    */
    function notifyRedemptionSettlement(string memory redemptionTransactionHash, string memory receiptHash)
        public whenNotPaused onlyResponsibleForSettlement {

        require (RBBLib.isValidHash(receiptHash), "O hash do recibo é inválido");
        emit RedemptionSettlement(redemptionTransactionHash, receiptHash);
    }

    //These methods may be necessary to solve incidents.
    function mintClient(uint clientId, uint idFinancialSupportAgreement,
        uint amount, string memory description) public onlyOwner {

        require(registry.isValidatedId(clientId), "Cliente precisa estar com conta blockchain validada");
        clientIdFCAmount[clientId][idFinancialSupportAgreement] = 
            clientIdFCAmount[clientId][idFinancialSupportAgreement].add(amount);
        emit ManualInterventionClient_MintAndBurn(clientId, idFinancialSupportAgreement, amount, description,1);
    }

    //These methods may be necessary to solve incidents.
    function burnClient(uint clientId, uint idFinancialSupportAgreement,
         uint amount, string memory description) public onlyOwner {
        
        require(registry.isValidatedId(clientId), "Cliente precisa estar com conta blockchain validada");
        clientIdFCAmount[clientId][idFinancialSupportAgreement] = 
            clientIdFCAmount[clientId][idFinancialSupportAgreement].sub(amount, "ERC20: burn amount exceeds balance");

        emit ManualInterventionClient_MintAndBurn(clientId, idFinancialSupportAgreement, amount, description,2);
    }

    //TODO: mint e burn para supplier


    function setResponsibleForDisbursement(uint idResponsible) onlyOwner public {
        require (registry.isValidatedId(idResponsible), "Id do Responsible for Disbursement não está validado");
        responsibleForDisbursement = idResponsible;
    }

    function setResponsibleForSettlement(uint idResponsible) onlyOwner public {
        require (registry.isValidatedId(idResponsible), "Id do Responsible for Settlement não está validado");
        responsibleForSettlement = idResponsible;
    }

    function isResponsibleForDisbursement(address addr) public view returns (bool) {
        return (registry.getId(addr) == responsibleForDisbursement);
    }

    function isResponsibleForSettlement(address addr) public view returns (bool) {
        return (registry.getId(addr) == responsibleForSettlement);
    }

    modifier onlyResponsibleForDisbursement() {
        require(isResponsibleForDisbursement(msg.sender), "Apenas o responsável pela liberação pode executar essa operação");
        _;
    }

    modifier onlyResponsibleForSettlement() {
        require(isResponsibleForSettlement(msg.sender), "Apenas o responsável pela liquidação pode executar essa operação");
        _;
    }

    function getDecimals() public view returns (uint8) {
        return decimals;
    }

}