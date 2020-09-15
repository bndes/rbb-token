pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./RBBToken.sol";
import "./SpecificRBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";


// Pode ter cliente no hash xyz, fornecedor no hash abc
// clientes no hash xyz são aqueles que bndes informou (set cliente no hash total)
/*
Regras específicas
- Toda vez que o BNDES faz um desembolso, o destinatário será associado como CLIENTE para um idFinancialSupportAgreement específico (se ainda não estiver associado).
- Somente clientes fazem pagamentos. Toda vez que um CLIENTE de um idFinancialSupportAgreement específico paga um fornecedor, o destinatário será associado como FORNECEDOR (se ainda não estiver associado). 
- Somente FORNECEDORES podem solicitar o resgate.

Todas as operações já supõem que a entidade de origem e destino estão cadastradas e validadas, pois isso é garantido pelo contrato genérico (RBB_Token)

Não incluído:
------------
- requisito adicional de o cliente poder resgatar uma parte do valor
- possibilidade de devolução de valores
    - pode ocorrer no final do contrato, por exemplo, porque sobrou algum valor
    - pode ocorrer no meio do contrato (glosa) e  normalmente se resolve aprovando uma comprovação da devolução para a conta bancária do projeto, sem precisar devolver ao BNDES. Mas tem alguns casos de devolução ao BNDES no meio do contrato, que ocorre em casos mais graves, e quando se quer ter mais controle sobre o uso do recurso
- ideia de o fornecedor poder sacar mais de um saldo ao mesmo tempo.

- qualquer pessoa do BNDES pode liberar (não é necessário verificar na blockchain)
*/

contract FABndesToken is SpecificRBBToken {

    //É o id, nao tem como especializar dentro do BNDES. Diferença no front-end
    uint public responsibleForSettlement;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) suppliers;

    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public PAY_SUPPLIER_VERIFICATION = "PAY_SUPPLIER_VERIFICATION";

    uint8 public RESERVED_NO_ADDITIONAL_FIELD_TO_HASH = 0;

    //ATENCAO: troquei cnpj por id no argumento do evento e tirei arg de contrato no resgate - impacto no BNDESTransparente
    event Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount);
    event TokenTransfer (uint fromCnpj, string fromIdFinancialSupportAgreement, uint toCnpj, uint amount);
    event RedemptionRequested (uint idClaimer, uint amount);
//    event RedemptionSettlement(string redemptionTransactionHash, string receiptHash);

//deveria nao receber (newRegistryAddr, newrbbTokenAddr) e serem setados no registro?
//O BNDES poderah verificar que o registry e token nao podem ser alterados.
    constructor (address newRegistryAddr, address newrbbTokenAddr, 
                 uint responsibleForSettlementArg)
                SpecificRBBToken (newRegistryAddr, newrbbTokenAddr)
                public {

        setResponsibleForSettlement(responsibleForSettlementArg);
    }

//TODO: tem que retornar o hash do fromHash e toHash tambem
    function getDisbusementData (string memory idFinancialSupportAgreement) public 
        returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));
        bytes32 toHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));

        string[] memory data = new string[](2);
        data[0] = DISBURSEMENT_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getPaySupplierData (string memory idFinancialSupportAgreement) public 
            returns (bytes32, bytes32, string[] memory) {


        bytes32 fromHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));
        bytes32 toHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](2);
        data[0] = PAY_SUPPLIER_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getRedeemData () public 
            returns (bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](0);
        return (fromHash, data);
    }


    function verifyAndActForTransfer(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused {

        string memory specificMethod = data[0];

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");


        if (RBBLib.isEqual(DISBURSEMENT_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_DISBURSEMENT(fromId, fromHash, toId, toHash, amount, data);
        }
        else if (RBBLib.isEqual(PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_PAY_SUPPLIER(fromId, fromHash, toId, toHash, amount, data);
        }
        else {
            require (false, "Nenhuma verificação específica encontrada para a transferência");
        }

    }

    function verifyAndActForTransfer_DISBURSEMENT(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        //Essa eh uma regra especifica visto que outra organizacao pode ter recebido o token no allocate.
        require (fromId == rbbToken.getBndesId(), "Responsável pela liberação de recursos não está correto");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do BNDES");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==toHash, "Erro no cálculo do hash da conta do cliente");

        if (!clients[toId][idFinancialSupportAgreement]) {
            clients[toId][idFinancialSupportAgreement] = true; //register the client
        }

        emit Disbursement (toId, idFinancialSupportAgreement, amount);

    }

    function verifyAndActForTransfer_PAY_SUPPLIER(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o pagamento");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId,
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        if (!suppliers[toId]) {
            suppliers[toId] = true; //register the supplier
        }

        emit TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount);

    }

    function verifyAndActForRedeem(uint fromId, bytes32 fromHash, uint amount, string[] memory data) public whenNotPaused {

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        require (suppliers[fromId], "Somente fornecedores podem executar o pagamento");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        emit RedemptionRequested (fromId, amount);

    }



//settlement deveria estar aqui mesmo? responsável pelo settlement será sempre o BNDES? Lembrar caso ANCINE
   /**
    * Using this function, the Responsible for Settlement indicates that he has made the FIAT money transfer.
    * @ param redemptionTransactionHash hash of the redeem transaction in which the FIAT money settlement occurred.
    * @ param receiptHash hash that proof the FIAT money transfer
    * / 
    function notifyRedemptionSettlement(string memory redemptionTransactionHash, string memory receiptHash)
        public whenNotPaused onlyResponsibleForSettlement {

        require (RBBLib.isValidHash(receiptHash), "O hash do recibo é inválido");
        emit RedemptionSettlement(redemptionTransactionHash, receiptHash);
    }
*/

//avaliar se deve passar pelo framework de mudanca (exceto construtor)
    function setResponsibleForSettlement(uint idResponsible) onlyOwner public {
        require (registry.isValidatedId(idResponsible), "Id do Responsible for Settlement não está validado");
        responsibleForSettlement = idResponsible;
    }
 
    function isResponsibleForSettlement(address addr) public view returns (bool) {
        return (registry.getId(addr) == responsibleForSettlement);
    }

    modifier onlyResponsibleForSettlement() {
        require(isResponsibleForSettlement(msg.sender), "Apenas o responsável pela liquidação pode executar essa operação");
        _;
    }
   
}