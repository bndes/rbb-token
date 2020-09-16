pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./RBBToken.sol";
import "./SpecificRBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";



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

//TODO: teoricamente, o cliente deveria registrar na blockchain o pedido de financiamento do cliente, concordam?

contract FABndesToken is SpecificRBBToken {

    //RBBId donor => true/false (registered or not)
    mapping (uint => bool) donors;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) suppliers;

   /* BNDES Fee percentage */
    uint256 public bndesFee;    

    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public PAY_SUPPLIER_VERIFICATION = "PAY_SUPPLIER_VERIFICATION";
//    string public RETURN_FROM_CLIENT_TO_BNDES_VERIFICATION = "RETURN_FROM_CLIENT_TO_BNDES_VERIFICATION";

    uint8 public RESERVED_NO_ADDITIONAL_FIELD_TO_HASH = 0;

     using SafeMath for uint;
   

//TODO: rever eventos para BNDES Transparente
    event FAB_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount);
    event FAB_TokenTransfer (uint fromCnpj, string fromIdFinancialSupportAgreement, uint toCnpj, uint amount);
    event FAB_RedemptionRequested (uint idClaimer, uint amount);
    event FAB_RedemptionSettlement(string redemptionTransactionHash, string receiptHash);

    event FAB_DonationBooked(uint idDonor, uint amount, uint tokenToBeMinted);
    event FAB_DonationConfirmed(string idDonor, uint amount, string receiptHash);

 //   event FAB_ManualIntervention_Returned_Client_BNDES (uint fromId, string idFinancialSupportAgreement, uint amount);
    event FAB_ManualIntervention_Fee(uint256 percent, string description);

    event FAB_DonorAdded(uint id);
    event FAB_ClientAdded(uint id);
    event FAB_SupplierAdded(uint id);


    constructor (uint fee) public {
        require (fee < 100, "Valor de Fee maior que 100%");
        bndesFee = fee;
    }

    function setBNDESFee(uint256 newBndesFee, string memory description) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FAB_ManualIntervention_Fee(newBndesFee, description);
    }

    function addDonor (uint idDonor) public onlyOwner {
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        if(!donors[idDonor]) {
            donors[idDonor] = true;
            emit FAB_DonorAdded(idDonor);
        }
    }

    /* Donor books a donation */
    function bookDonation(uint amount) public whenNotPaused  {        
        
        uint idDonor = registry.getId(msg.sender);

        require (donors[idDonor], "Somente doadores podem fazer doações");
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        
        bytes32 specificHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));
        uint tokenToBeMinted = amount.sub(amount.mul(bndesFee).div(100));

        rbbToken.requestMint(tokenToBeMinted, specificHash);

        emit FAB_DonationBooked(idDonor, amount, tokenToBeMinted);
    }
    
    /* confirms the donor's donation */
    function verifyAndActForMint(bytes32 specificHash, uint amountMinted, string[] memory data,
        string memory docHash) public whenNotPaused onlyRBBToken {

        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==specificHash, "Erro no cálculo do hash da doação");

        string memory idDonor = data[0];
//        require (donors[idDonor], "Somente doadores podem fazer doações, registro estah incorreto");

//TODO: transformar de string para uint de forma a ter eventos soh com uint         
        emit FAB_DonationConfirmed(idDonor, amountMinted, docHash);

    }

    //*********** */


    function getDisbusementData (string memory idFinancialSupportAgreement) public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));
        bytes32 toHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));

        string[] memory data = new string[](2);
        data[0] = DISBURSEMENT_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getPaySupplierData (string memory idFinancialSupportAgreement) public view
            returns (bytes32, bytes32, string[] memory) {


        bytes32 fromHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));
        bytes32 toHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](2);
        data[0] = PAY_SUPPLIER_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

/*
    function getReturnedClientToBNDESData (string memory idFinancialSupportAgreement) public 
        returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));
        bytes32 toHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](2);
        data[0] = RETURN_FROM_CLIENT_TO_BNDES_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }
*/
    function getRedeemData () public 
            returns (bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](0);
        return (fromHash, data);
    }

    //*********** */

    function verifyAndActForTransfer(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused onlyRBBToken {

        string memory specificMethod = data[0];

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");


        if (RBBLib.isEqual(DISBURSEMENT_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_DISBURSEMENT(fromId, fromHash, toId, toHash, amount, data);
        }
        else if (RBBLib.isEqual(PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_PAY_SUPPLIER(fromId, fromHash, toId, toHash, amount, data);
        }
//TODO: incluir intervencao manual. Owner do contrato aprova uma transferencia e o dono da carteira a executa?
        else {
            require (false, "Nenhuma verificação específica encontrada para a transferência");
        }

    }

    function verifyAndActForTransfer_DISBURSEMENT(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        //Essa eh uma regra especifica visto que outra organizacao pode ter recebido o token no allocate.
        require (fromId == rbbToken.getBndesId(), "Responsável pela liberação de recursos não está correto");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do BNDES");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==toHash, "Erro no cálculo do hash da conta do cliente");

        if (!clients[toId][idFinancialSupportAgreement]) {
            clients[toId][idFinancialSupportAgreement] = true; //register the client
            emit FAB_ClientAdded(toId);

        }

        emit FAB_Disbursement (toId, idFinancialSupportAgreement, amount);

    }

    function verifyAndActForTransfer_PAY_SUPPLIER(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o pagamento");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId,
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        if (!suppliers[toId]) {
            suppliers[toId] = true; //register the supplier
            emit FAB_SupplierAdded(fromId);
        }

        emit FAB_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount);

    }
/*    
//TODO: incluir no metodo publico, tratar como caso geral de tratamento de erros ou nao?
    function verifyAndActForTransfer_RETURN_CLIENT_BNDES(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o retorno de recursos");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do BNDES");

        emit FAB_ManualIntervention_Returned_Client_BNDES (fromId, idFinancialSupportAgreement, amount);

    }
*/
    function verifyAndActForRedeem(uint fromId, bytes32 fromHash, uint amount, string[] memory data) 
        public whenNotPaused onlyRBBToken {

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        require (suppliers[fromId], "Somente fornecedores podem executar o pagamento");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        emit FAB_RedemptionRequested (fromId, amount);

    }

    function verifyAndActForRedemptionSettlement(string memory redemptionTransactionHash, string memory receiptHash, 
        string[] memory data)
        public whenNotPaused onlyRBBToken {

        emit FAB_RedemptionSettlement (redemptionTransactionHash, receiptHash);
    }

    modifier onlyRBBToken() {
        require (msg.sender==address(rbbToken), "Esse método só pode ser chamado pelo RBB_Token");
        _;
    }
   
}