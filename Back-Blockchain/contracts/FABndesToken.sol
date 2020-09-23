pragma solidity ^0.6.0;
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
- ideia de o fornecedor poder sacar mais de um saldo ao mesmo tempo.
- pedido inicial de financiamento do cliente 
- devolução de fornecedor para cliente sem anuência para o BNDES

*/


contract FABndesToken is SpecificRBBToken {

    //RBBId donor => true/false (registered or not)
    mapping (uint => bool) donors;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) suppliers;

   /* Hash of approved ManualInterventionOperationApprovedByOwner */
    bytes32[] public hashManualInterventionOperationApprovedByOwner;


   /* BNDES Fee percentage */
    uint256 public bndesFee;    

    string public INITIAL_ALLOCATION = "INITIAL_ALLOCATION";
    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public CLIENT_PAY_SUPPLIER_VERIFICATION = "CLIENT_PAY_SUPPLIER_VERIFICATION";
    string public BNDES_PAY_SUPPLIER_VERIFICATION = "BNDES_PAY_SUPPLIER_VERIFICATION";
    string public MANUAL_INTERVENTION = "MANUAL_INTERVENTION";

    address public responsibleForDonationConfirmation;
    address public responsibleForDisbursement;
    address public resposibleForExtraordinaryTransfers;
    address public responsibleForSettlement;

    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH = 0;
    uint8 public RESERVED_MINTED_ACCOUNT = 1;
    uint8 public RESERVED_TO_USUAL_DISBURSEMENTS_ACCOUNT = 2;
    uint8 public RESERVED_BNDES_ADMIN_FEE__TO_HASH = 3;


//TODO: get para isso ADMIN_FEE
//TODO: initial allocation transfer do MINTED para RESERVED_TO_USUAL_DISBURSEMENTS_ACCOUNT e ADMIN e 

     using SafeMath for uint;
   

//TODO: rever eventos para BNDES Transparente
    event FA_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount);
    event FA_TokenTransfer (uint fromCnpj, string fromIdFinancialSupportAgreement, uint toCnpj, uint amount);
    event FA_RedemptionRequested (uint idClaimer, uint amount);
    event FA_RedemptionSettlement(string redemptionTransactionHash, string receiptHash);
    event FA_BNDES_TokenTransfer(uint toCnpj, uint amount);

    event FA_DonationBooked(uint idDonor, uint amount);
    event FA_DonationConfirmed(string idDonor, uint amount, string receiptHash);
    event FA_AdmFeeCharged(string idDonor, uint amount);
    

    event FA_ManualIntervention_TransferAllowed (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount);
    event FA_ManualIntervention_Transfer(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] data);
    event FA_ManualIntervention_Fee(uint256 percent, string description);
    event FA_ManualIntervention_RoleOrAddress(address account, uint8 eventType);

    event FA_DonorAdded(uint id);
    event FA_ClientAdded(uint id);
    event FA_SupplierAdded(uint registeredBy, uint id);

//TODO: verificar papeis nos metodos abaixo
    constructor (uint fee) public {
        require (fee < 100, "Valor de Fee maior que 100%");

        responsibleForDonationConfirmation = msg.sender;
        responsibleForDisbursement = msg.sender;
        resposibleForExtraordinaryTransfers = msg.sender;
        responsibleForSettlement = msg.sender;

        bndesFee = fee;
    }


    function setBNDESFee(uint256 newBndesFee, string memory description) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FA_ManualIntervention_Fee(newBndesFee, description);
    }

    function addDonor (uint idDonor) public onlyOwner {
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        if(!donors[idDonor]) {
            donors[idDonor] = true;
            emit FA_DonorAdded(idDonor);
        }
    }

    /* Donor books a donation */
    function bookDonation(uint amount) public whenNotPaused  {        
        
        uint idDonor = registry.getId(msg.sender);

        require (donors[idDonor], "Somente doadores podem fazer doações");
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        
        bytes32 specificHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH));
        rbbToken.requestMint(specificHash, idDonor, amount);

        emit FA_DonationBooked(idDonor, amount);
    }
    
    /* confirms the donor's donation */
    function verifyAndActForMint(bytes32 specificHash, uint amount, string[] memory data,
        string memory docHash) public override whenNotPaused onlyRBBToken {

        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH))==specificHash, "Erro no cálculo do hash da doação");

        string memory idDonor = data[0];
//        require (donors[idDonor], "Somente doadores podem fazer doações, registro estah incorreto");

//TODO: transformar de string para uint de forma a ter eventos soh com uint
        emit FA_DonationConfirmed(idDonor, amount, docHash);

    }

    //*********** */

    function getHashToMintedAccount(bytes32 specificHash) override public returns (bytes32) {
        //There is no difference of specificHash, all money should be minted in the same account
        return keccak256(abi.encodePacked(RESERVED_MINTED_ACCOUNT));
    }


    function getDisbusementData (string memory idFinancialSupportAgreement) public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_TO_USUAL_DISBURSEMENTS_ACCOUNT));
        bytes32 toHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));

        string[] memory data = new string[](2);
        data[0] = DISBURSEMENT_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getPaySupplierData (string memory idFinancialSupportAgreement) public view
            returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));
        bytes32 toHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH));

        string[] memory data = new string[](2);
        data[0] = CLIENT_PAY_SUPPLIER_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }


    function getRedeemData () public 
            returns (bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH));

        string[] memory data = new string[](0);
        return (fromHash, data);
    }

    //*********** */


    function verifyAndActForTransfer(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public override whenNotPaused onlyRBBToken {

        string memory specificMethod = data[0];

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");


        if (RBBLib.isEqual(DISBURSEMENT_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_DISBURSEMENT(fromId, fromHash, toId, toHash, amount, data);
        }
        else if (RBBLib.isEqual(CLIENT_PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_CLIENT_PAY_SUPPLIER(fromId, fromHash, toId, toHash, amount, data);
        }
        else if (RBBLib.isEqual(BNDES_PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_BNDES_PAY_SUPPLIER(fromId, fromHash, toId, toHash, amount, data);
        }
        else if (RBBLib.isEqual(MANUAL_INTERVENTION, specificMethod)) {
            verifyAndActForTransfer_MANUAL_INTERVENTION(fromId, fromHash, toId, toHash, amount, data);
        }
        else {
            require (false, "Nenhuma verificação específica encontrada para a transferência");
        }

    }

//        uint admFee = amount.mul(bndesFee).div(100);
//        rbbToken.burn(admFee);

//terminar isso
    function verifyAndActForTransfer_INITIAL_ALLOCATION(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
//TODO: FAZER    
        uint ownerId = registry.getId(owner());


//TODO
//        emit FA_Disbursement (toId, idFinancialSupportAgreement, amount);

    }


//TODO: incluir msg.sender aqui e testar que é o resposibleForSettlement
    function verifyAndActForTransfer_DISBURSEMENT(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];
        uint ownerId = registry.getId(owner());

        //Essa eh uma regra especifica visto que outra organizacao pode ter recebido o token no allocate.
        require (fromId == ownerId, "Responsável pela liberação de recursos não está correto");
        require (keccak256(abi.encodePacked(RESERVED_TO_USUAL_DISBURSEMENTS_ACCOUNT))==fromHash, "Erro no cálculo do hash da conta do BNDES");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==toHash, "Erro no cálculo do hash da conta do cliente");

        if (!clients[toId][idFinancialSupportAgreement]) {
            clients[toId][idFinancialSupportAgreement] = true; //register the client
            emit FA_ClientAdded(toId);

        }

        emit FA_Disbursement (toId, idFinancialSupportAgreement, amount);

    }

    function verifyAndActForTransfer_CLIENT_PAY_SUPPLIER(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o pagamento");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH))==toHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId,
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        if (!suppliers[toId]) {
            suppliers[toId] = true; //register the supplier
            emit FA_SupplierAdded(fromId, toId);
        }

        emit FA_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount);

    }



    function verifyAndActForTransfer_BNDES_PAY_SUPPLIER(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        require (fromId==registry.getId(owner()), "Somente o BNDES pode executar o pagamento");
        require (keccak256(abi.encodePacked(RESERVED_BNDES_ADMIN_FEE__TO_HASH))==fromHash, "Erro no cálculo do hash da conta de admin do contrato especifico");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH))==toHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId, "Um BNDES não pode transferir token para si");

        emit FA_BNDES_TokenTransfer (toId, amount);

    }

    function addSupplier (uint id) public onlyOwner {
        if (!suppliers[id]) {
            suppliers[id] = true; //register the supplier
            emit FA_SupplierAdded(registry.getId(owner()), id);
        }
    }


    

    function verifyAndActForRedeem(uint fromId, bytes32 fromHash, uint amount, string[] memory data) 
        public override whenNotPaused onlyRBBToken {

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        require (suppliers[fromId], "Somente fornecedores podem executar o pagamento");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELDS_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        emit FA_RedemptionRequested (fromId, amount);

    }

    function verifyAndActForRedemptionSettlement(string memory redemptionTransactionHash, string memory receiptHash, 
        string[] memory data)
        public override whenNotPaused onlyRBBToken {

        emit FA_RedemptionSettlement (redemptionTransactionHash, receiptHash);
    }

    modifier onlyRBBToken() {
        require (msg.sender==address(rbbToken), "Esse método só pode ser chamado pelo RBB_Token");
        _;
    }

    
    //*********** MANUAL INTERVENTION  */

//TODO: ver se todos os hash sao calculados com uma info e mudar por esse metodo
    function getCalculatedHash (string memory info) public returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }

//TODO: campo de justificativa
//TODO: incluir periodo de validade para essa autorizacao
    function authorizeExtraordinaryTransfer (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount) public onlyOwner {
        
        require (hasRoleInThisContract(fromId, fromHash), "Endereço de origem não incluído como papel nesse cadastro");
        require (hasRoleInThisContract(toId, toHash), "Endereço de destino não incluído como papel nesse cadastro");

        bytes32 m = keccak256(abi.encodePacked(fromId, fromHash, toId, toHash, amount));
        hashManualInterventionOperationApprovedByOwner.push(m);

        emit FA_ManualIntervention_TransferAllowed (fromId, fromHash, toId, toHash, amount);

    }
   
    function verifyAndActForTransfer_MANUAL_INTERVENTION(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {

        require (hasRoleInThisContract(fromId, fromHash), "Endereço de origem não incluído como papel nesse cadastro");
        require (hasRoleInThisContract(toId, toHash), "Endereço de destino não incluído como papel nesse cadastro");

        string memory idFinancialSupportAgreement = data[1];
        bytes32 m = keccak256(abi.encodePacked(fromId, fromHash, toId, toHash, amount));

        bool interventionExecuted = false;
        uint index = 0;
        for (; index<hashManualInterventionOperationApprovedByOwner.length; index++) {
            if (hashManualInterventionOperationApprovedByOwner[index] == m) {
                interventionExecuted = true;
                break;
            }
        }

        require (interventionExecuted, "Intervenção manual não previamente cadastrada");

        hashManualInterventionOperationApprovedByOwner[index] 
            = hashManualInterventionOperationApprovedByOwner [hashManualInterventionOperationApprovedByOwner.length-1];
        hashManualInterventionOperationApprovedByOwner.pop();

        emit FA_ManualIntervention_Transfer (fromId, fromHash, toId, toHash, amount, data);

    }

    function hasRoleInThisContract (uint rbbId, bytes32 hashToAccount) private returns (bool) {

        bool hasRole = false;
        if (donors[rbbId]==true) return true;

//TODO: resolver
//        if (clients[rbbId]!=0) return true;
        if (suppliers[rbbId]==true) return true;

        uint ownerId = registry.getId(owner());
        if (ownerId == rbbId) return true;

        uint rbbTokenOwnerId = registry.getId(rbbToken.owner());
        if (rbbTokenOwnerId == rbbId) return true;

        return false;
    }


 /**
    * By default, the owner is also the Responsible for Donation Confirmation. 
    * The owner can assign other address to be the Responsible for Donation Confirmation. 
    * @param rs Ethereum address to be assigned as Responsible for Donation Confirmation.
    */
    function setResponsibleForDonationConfirmation(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pela confirmação doação deve ser da mesmo RBB_ID do contrato");
        responsibleForDonationConfirmation = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 1);
    }

   /**
    * By default, the owner is also the Responsible for Disbursment. 
    * The owner can assign other address to be the Responsible for Disbursment. 
    * @param rs Ethereum address to be assigned as Responsible for Disbursment.
    */
    function setResponsibleForDisbursement(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pelo desembolso deve ser da mesmo RBB_ID do contrato");
        responsibleForDisbursement = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 2);
    }

   /**
    * By default, the owner is also the Responsible for Extraordinary Transfers. 
    * The owner can assign other address to be the Resposible Extraordinary Transfers. 
    * @param rs Ethereum address to be assigned as Responsible for Extraordinary Transfers.
    */
    function setResposibleForExtraordinaryTransfers(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pelo cadastramento de transferencias extraordinárias deve ser da mesmo RBB_ID do contrato");
        resposibleForExtraordinaryTransfers = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 3);
    }

   /**
    * By default, the owner is also the Responsible for Settlement. 
    * The owner can assign other address to be the Responsible for Settlement. 
    * @param rs Ethereum address to be assigned as Responsible for Settlement.
    */
    function setResponsibleForSettlement(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pela liquidação deve ser da mesmo RBB_ID do contrato");
        responsibleForSettlement = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 4);
    }


}