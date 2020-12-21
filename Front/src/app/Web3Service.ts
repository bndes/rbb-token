import { Injectable  } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from './ConstantesService';
import { formattedError } from '@angular/compiler';
import {ethers} from 'ethers';


@Injectable()
export class Web3Service {

    private serverUrl: string;

    private ethereum: any;
    private provider: any;
    private netVersion: any;
    private accountProvider: any;

    private addrContratoRBBToken: string = '';
    private addrContratoESGBndesToken: string = '';
    private addrContratoESGBndesToken_GetDataToCall: string = '';
    private addrContratoRBBRegistry: string = '';
    private addrContratoESGBndesToken_BNDESRoles: string ="";

    private abiRBBToken: string = '';
    private abiESGBndesToken: string = '';
    private abiESGBndesToken_GetDataToCall: string = ''; 
    private abiRBBRegistry: string = '';
    private abiESGBndesToken_BNDESRoles: string = ''; 

    private rbbTokenSmartContract: any;
    private esgBndesTokenSmartContract: any;
    private esgBndesToken_GetDataToCallSmartContract: any;
    private rbbRegistrySmartContract: any;
    private ESGBndesToken_BNDESRolesSmartContract: any;
    

    private URLBlockchainExplorer: string;
    private nomeRedeBlockchain: string;
    private numeroBlockchainNetwork: string = '';
    private URLBlockchainProvider: string;

    private vetorTxJaProcessadas : any[];

    private decimais : number;

    private FAKE_HASH = ethers.constants.HashZero;

//VARIAVEIS DO SMART CONTRACT
    private ID_SPECIFIC_TOKEN: number = 1;
    private ID_BNDES: number = 1;

    private RESERVED_MINTED_ACCOUNT: number = 0; 
    private RESERVED_USUAL_DISBURSEMENTS_ACCOUNT: number = 1; 
    private RESERVED_BNDES_ADMIN_FEE_TO_HASH: number = 2;

    private RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER: number = 20;


    constructor(private http: HttpClient, private constantes: ConstantesService) {
       
        this.vetorTxJaProcessadas = [];

        this.serverUrl = ConstantesService.serverUrl;
        let url = this.serverUrl + 'constantesFront';
        console.log("Web3Service.ts :: Selecionou URL = " + url);

        this.http.post<Object>(url, {}).subscribe(
            data => {

                console.log("POST DO SERVER configurando atributos front");


                this.numeroBlockchainNetwork = data["blockchainNetwork"];
                this.URLBlockchainExplorer = data["URLBlockchainExplorer"];
                this.URLBlockchainProvider = data["URLBlockchainProvider"];
                this.nomeRedeBlockchain = data["nomeRedeBlockchain"];
    
                this.addrContratoRBBToken = data["addrContratoRBBToken"];
                this.addrContratoESGBndesToken = data["addrContratoESGBndesToken"];
                this.addrContratoESGBndesToken_GetDataToCall = data["addrContratoESGBndesToken_GetDataToCall"];
                this.addrContratoRBBRegistry = data["addrContratoRBBRegistry"];
                this.addrContratoESGBndesToken_BNDESRoles=data["addrContratoESGBndesToken_BNDESRoles"];
    
                this.abiRBBToken = data['abiRBBToken'];
                this.abiESGBndesToken = data['abiESGBndesToken'];
                this.abiESGBndesToken_GetDataToCall = data['abiESGBndesToken_GetDataToCall']; 
                this.abiRBBRegistry = data['abiRBBRegistry'];
                this.abiESGBndesToken_BNDESRoles = data['abiESGBndesToken_BNDESRoles'];

                this.intializeWeb3();

            },
            error => {
                console.log("**** Erro ao buscar constantes do front");
            });
            
    }

 
    async intializeWeb3() {

        console.log("this.URLBlockchainProvider = " + this.URLBlockchainProvider);
        this.provider = new ethers.providers.JsonRpcProvider(this.URLBlockchainProvider);
        this.ethereum =  window['ethereum'];

        this.netVersion = await this.ethereum.request({
            method: 'net_version',
        });
        console.log(this.netVersion);

        this.accountProvider = new ethers.providers.Web3Provider(this.ethereum);

        console.log("accountProvider=");
        console.log(this.accountProvider);        

        console.log("INICIALIZOU O WEB3 - rbbTokenSmartContract abaixo");
        console.log("this.addrContratoRBBToken=" + this.addrContratoRBBToken);

        this.rbbTokenSmartContract = new ethers.Contract(this.addrContratoRBBToken, this.abiRBBToken, this.provider);
        this.esgBndesTokenSmartContract = new ethers.Contract(this.addrContratoESGBndesToken,this.abiESGBndesToken, this.provider);
        this.esgBndesToken_GetDataToCallSmartContract = new ethers.Contract(this.addrContratoESGBndesToken_GetDataToCall, this.abiESGBndesToken_GetDataToCall, this.provider);
        this.rbbRegistrySmartContract = new ethers.Contract(this.addrContratoRBBRegistry, this.abiRBBRegistry, this.provider);
        this.ESGBndesToken_BNDESRolesSmartContract= new ethers.Contract(this.addrContratoESGBndesToken_BNDESRoles, this.abiESGBndesToken_BNDESRoles, this.provider);


        console.log("todos os contratos lidos");
        
        

this.inicializaQtdDecimais();
        console.log("this.decimais=" + this.decimais);

    } 


    async getBlockTimestamp(blockNumber: number) {

        let block = await this.provider.getBlock(blockNumber);
        return block.timestamp;

    }


    public getInfoBlockchain(): any {

        return {

            URLBlockchainExplorer: this.URLBlockchainExplorer,
            nomeRedeBlockchain: this.nomeRedeBlockchain,
            numeroBlockchainNetwork: this.numeroBlockchainNetwork,
            addrContratoRBBToken: this.addrContratoRBBToken,
            addrContratoESGBndesToken: this.addrContratoESGBndesToken,
            addrContratoRBBRegistry: this.addrContratoRBBRegistry,
            URLBlockchainProvider: this.URLBlockchainProvider,

            netVersion: this.netVersion
        };
    }


    public getCurrentAccountSync() {
        return this.accountProvider.getSigner().getAddress();
    }

    conectar () {
        this.ethereum.enable();
    }

    async inicializaQtdDecimais() {
        this.decimais = await this.rbbTokenSmartContract.getDecimals();
        console.log("this.decimais=" + this.decimais);
        return this.decimais;
    }

    converteDecimalParaInteiro( _x : number ): number {
        let v = _x * ( 10 ** this.decimais);
        return ( Math.floor(v) );
    }

    converteInteiroParaDecimal( _x: number ): number {    
        return ( _x / ( 10 ** this.decimais ) ) ;
    }


    ////////////////////// INICIO EVENTOS E MENSAGENS

//TODO: tirar "FA" do início do nome do evento

    async recuperaEventosAdicionaInvestidor() {

        let filter = this.esgBndesTokenSmartContract.filters.FA_InvestorAdded(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
/*
        //TODO: avaliar se funciona para ler novos eventos
        let topic = ethers.utils.id("FA_InvestorAdded(uint id");
        filter = {
            address: this.addrContratoESGBndesToken,
            topics: [ topic ]
        };

        this.provider.on(filter, (result) => {
            console.log("dentro do evento do eethers do associa inv");
            console.log(result);
        });
*/

    }

    async recuperaEventosAdicionaCliente() {
        console.log("FILTROS");

        console.log(this.esgBndesTokenSmartContract.filters);
        let filter = this.esgBndesTokenSmartContract.filters.FA_ClientAdded(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosAdicionaFornecedor() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_SupplierAdded(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosRegistrarInvestimento() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InvestmentBooked(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosRecebimentoInvestimento() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InvestmentConfirmed(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosAlocacaoParaDesembolso() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InitialAllocation_Disbursements(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);

    }

    async recuperaEventosAlocacaoParaContaAdm() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InitialAllocation_Fee(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosLiberacao() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_Disbursement(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosPagamentoFornecedores() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_TokenTransfer(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosBNDESPagaFornecedores() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_BNDES_TokenTransfer(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }    
    
    async recuperaEventosResgate() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_RedemptionRequested(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosLiquidacaoResgate() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_RedemptionSettlement(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    //TODO: melhorar para buscar diretamente pelo hash do evento
    async recuperaEventosResgateByHash(hash) {
        let filter = this.esgBndesTokenSmartContract.filters.FA_RedemptionRequested(null);
        let eventos = await this.esgBndesTokenSmartContract.queryFilter(filter);
        for (let i=0; i<eventos.length; i++) {
            if (eventos[i].transactionHash == hash) {
                return eventos[i];
            }
          }
        return null; 
    }    

 //TODO: alterar esses eventos para dashboard de intervencoes manuais.
    async registraEventosIntervencaoManualMintBurn() {
        console.log("web3-registraEventosIntervencaoManual");

    }
    
    async registraEventosIntervencaoManualFee() {
        console.log("web3-registraEventosIntervencaoManualFee");        
//TODO
    }
    async registraEventosIntervencaoManualRoleOrAddress() {
        console.log("web3-registraEventosIntervencaoManual-RoleOrAddress");        
//TODO
    }



    registraWatcherEventosLocal(txHashProcurado, callback) {
        
        let self = this;
        console.info("Callback ", callback);
        console.info("txHashProcurado= ", txHashProcurado);

        this.rbbTokenSmartContract.on("*", function(evento) {
            self.processaEventoParaChamadaCallback(evento,txHashProcurado,callback);
        });
        this.esgBndesTokenSmartContract.on("*", function(evento) {
            self.processaEventoParaChamadaCallback(evento,txHashProcurado,callback);
        });
        
    }

    processaEventoParaChamadaCallback(evento, txHashProcurado, callback) {
        if (evento.transactionHash == txHashProcurado) {
            if (!this.vetorTxJaProcessadas.includes(txHashProcurado)) {
                this.vetorTxJaProcessadas.push(txHashProcurado);
                callback();    
            }
        }    
    }

    ////////////////////// INICIO REGISTRY

    async getRBBIDByCNPJSync(cnpj: number) {
        let id = await this.rbbRegistrySmartContract.getIdFromCNPJ(cnpj);
        return id.toNumber();
    }    

    async getCNPJByAddressSync(addr: string) {
        let result = await this.rbbRegistrySmartContract.getRegistry(addr);
        let id = result[1];
        return id.toNumber();
    }    

    async getIdByAddressSync(addr: string) {
        let result = await this.rbbRegistrySmartContract.getRegistry(addr);
        let id = result[0];
        return id; 
    }    

    async getRegistryByAddressSync(addr: string) {
        let result = await this.rbbRegistrySmartContract.getRegistry(addr);
        let registry: {id: number, cnpj: string} 
        registry = {id: (<number>result[0]), cnpj: (<string>result[1])};
        return registry;
    }
    getCnpjByRBBId(id: number) {
        return this.rbbRegistrySmartContract.getCNPJbyID(id);
    }
    

    ////////////////////// FIM REGISTRY

    ////////////////////// INICIO INVESTIDOR


    async associaInvestidor(rbbID: number): Promise<any> {

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.esgBndesTokenSmartContract.connect(signer);
        return (await contWithSigner.addInvestor(rbbID));
    }

    async registrarInvestimento(amount: number): Promise<any> {
        
        console.log("Registra doacao!!! " + amount);
        console.log("this.decimais= " + this.decimais);
        
        amount = this.converteDecimalParaInteiro(amount);     
        console.log("Amount=" + amount);
        console.log("this.FAKE_HASH)=" + this.FAKE_HASH);

        let amountAsBigNumber = ethers.BigNumber.from(amount);
        console.log("AmountBigN=" + amountAsBigNumber);

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.esgBndesTokenSmartContract.connect(signer);

        return (await contWithSigner.bookInvestment(amountAsBigNumber, this.FAKE_HASH));        
    }

    async getSpecificHashAsUint (info: number)  {
        
        console.log("getSpecificHashUin " + info);
        console.log(this.esgBndesToken_GetDataToCallSmartContract);
        let value = await this.esgBndesToken_GetDataToCallSmartContract.getCalculatedHashUint(info);
        
        return value;
    }

    async getSpecificHashAsString (info: string)  {
        console.log("getSpecificHashString " + info);
        console.log(this.esgBndesToken_GetDataToCallSmartContract);
        let value = await this.esgBndesToken_GetDataToCallSmartContract.getCalculatedHashString(info);
        return value;
    }


    async getBalanceRequestedToken(rbbId: number): Promise <number> {
        
        console.log("vai recuperar o balanceOf de " + rbbId);
        let self = this;

        //TODO: resolver o que fazer porque não temos um saldo de investidor isolado
        let specificHash = <string> (await this.getSpecificHashAsUint(30));

        let retornedValue = await this.rbbTokenSmartContract.balanceRequestedTokens(this.ID_SPECIFIC_TOKEN, rbbId, specificHash);

        return self.converteInteiroParaDecimal( retornedValue.toNumber() );
    }


    async receberDoacao(rbbIDInvestor: number, amount: number, docHash: string): Promise<any> {
        
        console.log("***** Web3Service - ReceberDoacao 2");
        amount = this.converteDecimalParaInteiro(amount); 
        console.log("amount=" + amount);
        console.log("inv=" + rbbIDInvestor);
        console.log("addr=" + this.addrContratoESGBndesToken);
        console.log("docHash=" + docHash);


        //TODO: resolver o que fazer porque não temos um saldo de investidor isolado
        let specificHash = <string> (await this.getSpecificHashAsUint(30));

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);

        return (await contWithSigner.mint(this.addrContratoESGBndesToken, rbbIDInvestor, specificHash, 
            amount, docHash, []));  
    }  

    ////////////////// FIM INVESTIDOR

    ////////////////// INICIO SALDOS

    async getBalanceOf(rbbId: number, numeroContrato: number) {
        
        console.log("getBalanceOf  de " + rbbId);

        let specificHash = "";
        if (numeroContrato) {
            let valorToHash = numeroContrato+"";
            specificHash =  <string> (await this.getSpecificHashAsString(valorToHash));
        }
        else {
            

            //let valorToHash = 2;
            let valorToHash = this.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER;//ver aqui
            specificHash = <string> (await this.getSpecificHashAsUint(valorToHash));
        }

        console.log("specificHash= " + specificHash);

        let valorRetornado = await this.rbbTokenSmartContract.rbbBalances(this.ID_SPECIFIC_TOKEN,rbbId,specificHash);

        return this.converteInteiroParaDecimal(valorRetornado.toNumber());

    }
// mostrar para suzana é parecida com a getBalanceOf
    async getBndesBalanceOf (rbbId: number, numeroContrato: number) {
        
        console.log("getBalanceOf  de " + rbbId);

        let specificHash = "";
        if (numeroContrato) {
            let valorToHash = numeroContrato+"";
            specificHash =  <string> (await this.getSpecificHashAsString(valorToHash));
        }
        else {
            

            
            let valorToHash = this.RESERVED_BNDES_ADMIN_FEE_TO_HASH;//ver aqui
            specificHash = <string> (await this.getSpecificHashAsUint(valorToHash));
        }

        console.log("specificHash= " + specificHash);

        let valorRetornado = await this.rbbTokenSmartContract.rbbBalances(this.ID_SPECIFIC_TOKEN,rbbId,specificHash);

        return this.converteInteiroParaDecimal(valorRetornado.toNumber());

    }



    async getBalanceOfAllAccounts(rbbId: number, valorToHash: number) {
        
        console.log("vai recuperar o balanceOf all accounts de " + rbbId + " " + valorToHash);

        let specificHash =  <string> (await this.getSpecificHashAsUint(valorToHash));
        let valorRetornado = await this.rbbTokenSmartContract.rbbBalances(this.ID_SPECIFIC_TOKEN,rbbId,specificHash);

        return this.converteInteiroParaDecimal(valorRetornado.toNumber());

    }

    async getMintedBalance() {

        return this.getBalanceOfAllAccounts(this.ID_BNDES, this.RESERVED_MINTED_ACCOUNT);

    }

    async getDisbursementBalance() {

        return this.getBalanceOfAllAccounts(this.ID_BNDES, this.RESERVED_USUAL_DISBURSEMENTS_ACCOUNT);

    }

    async getAdminFeeBalance() {

        return this.getBalanceOfAllAccounts(this.ID_BNDES, this.RESERVED_BNDES_ADMIN_FEE_TO_HASH);

    }

    ////////////////// FIM SALDOS

    ////////////////// INÍCIO METODOS DE TRANSFER
    async alocaRecursosDesembolso(rbbIdBNDES: number, transferAmount: number) : Promise<any> {

        console.log("Web3Service - alocaRecursosDesembolso");

        let alocaRecursosData = await this.esgBndesToken_GetDataToCallSmartContract.getInitialAllocationToDisbusementData();
        let fromHash = alocaRecursosData[0];
        console.log(fromHash);

        let toHash = alocaRecursosData[1];
        console.log(toHash);

        let dataFromDD = alocaRecursosData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        
        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);
 
        return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdBNDES, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));
    
    }
    async alocaRecursosDesembolso2(rbbIdBNDES: number, transferAmount: number) : Promise<any> {

        console.log("Web3Service - alocaRecursosDesembolso");

        let alocaRecursosData = await this.esgBndesToken_GetDataToCallSmartContract.getInitialAllocationToChargeFeeData();
        let fromHash = alocaRecursosData[0];
        console.log(fromHash);

        let toHash = alocaRecursosData[1];
        console.log(toHash);

        let dataFromDD = alocaRecursosData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        
        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);
 
        return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdBNDES, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));
    
    }
    



    async liberacao(rbbIdDestino: number, nContrato: string, transferAmount: number) : Promise<any> {
        console.log("Web3Service - Liberacao");

        let disbursementData = await this.esgBndesToken_GetDataToCallSmartContract.getDisbusementData(nContrato);
        console.log(disbursementData);
        let fromHash = disbursementData[0];
        console.log(fromHash);

        let toHash = disbursementData[1];
        console.log(toHash);

        let dataFromDD = disbursementData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        console.log('TransferAmount(after)=' + transferAmount);

       const signer = this.accountProvider.getSigner();
       const contWithSigner = this.rbbTokenSmartContract.connect(signer);
       
       return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdDestino, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));

    }

    async pagaFornecedor(nContratoOrigem: string, rbbIdDestino: number, transferAmount: number) : Promise<any> {
        
        console.log("Web3Service - PagarFornecedor");

        let callData = await this.esgBndesToken_GetDataToCallSmartContract.getClientPaySupplierData(nContratoOrigem);
        console.log(callData);
        let fromHash = callData[0];
        console.log(fromHash);

        let toHash = callData[1];
        console.log(toHash);

        let dataFromDD = callData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        console.log('TransferAmount(after)=' + transferAmount);

       const signer = this.accountProvider.getSigner();
       const contWithSigner = this.rbbTokenSmartContract.connect(signer);
       
       return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdDestino, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));

    }
    async bndesPagaFornecedor( rbbIdDestino: number, transferAmount: number) : Promise<any> {
        
        console.log("Web3Service - PagarFornecedor");

        let callData = await this.esgBndesToken_GetDataToCallSmartContract.getBNDESPaySupplierData();
        console.log(callData);
        let fromHash = callData[0];
        console.log(fromHash);

        let toHash = callData[1];
        console.log(toHash);

        let dataFromDD = callData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  

        console.log('TransferAmount(after)=' + transferAmount);

       const signer = this.accountProvider.getSigner();
       const contWithSigner = this.rbbTokenSmartContract.connect(signer);
       
       return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdDestino, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));

    }



    async resgata(transferAmount: number) {

        console.log("Web3Service - Redeem");

        let callData = await this.esgBndesToken_GetDataToCallSmartContract.getRedeemData();
        let fromHash = callData[0];
        let dataFromDD = callData[1];

        transferAmount = this.converteDecimalParaInteiro(transferAmount);     
        console.log('this.addrContratoESGBndesToken=' + this.addrContratoESGBndesToken);
        console.log('fromHash=' + fromHash);
        console.log('this.FAKE_HASH=' + this.FAKE_HASH);
        console.log('TransferAmount(after)=' + transferAmount);
        console.log(dataFromDD);

       const signer = this.accountProvider.getSigner();
       const contWithSigner = this.rbbTokenSmartContract.connect(signer);


       
       return (await contWithSigner.redeem (
            this.addrContratoESGBndesToken, fromHash, transferAmount, this.FAKE_HASH, dataFromDD));

    }

    async liquidaResgate(hashResgate: any, hashComprovante: any) {
        console.log("Web3Service - liquidaResgate")
        console.log("HashResgate - " + hashResgate)
        console.log("HashComprovante - " + hashComprovante)

//        console.log("isOk - " + isOk)
//TODO: Avaliar se precisa incluir o isOk --->  impacto no smart contract
        let emptyData: String[];
        emptyData = new Array<String>();

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);

        return (await contWithSigner.notifyRedemptionSettlement (
                this.addrContratoESGBndesToken, hashResgate, hashComprovante, emptyData));
            
    }


    //TODO: ajustar TODOS OS metodos ABAIXO para perguntar pelo papel correto 

    /*
    getConfirmedTotalSupply(fSuccess: any, fError: any): number {

    console.log("vai recuperar o confirmedtotalsupply. " );
    let self = this;


    return this.rbbTokenSmartContract.rbbBalances[]()
        (error, confirmedTotalSupply) => {
            if (error) fError(error);
            else fSuccess( self.converteInteiroParaDecimal(  parseInt ( confirmedTotalSupply ) ) );
        });
       return -1;           
         
 
    }

*/

    async isResponsavelPorAssociarInvestidorSync () {

        let owner = await this.esgBndesTokenSmartContract.owner();
        let address = await this.accountProvider.getSigner().getAddress();
        console.log("isResponsavelPorAssociarInvestidorSync=");
        console.log(owner);

        return owner == address;
    }
  
    isClienteSync(address: string) {
        return false;
    }

    isDoadorSync(address: string) {
        return false;
    }

    isResponsibleForDonationConfirmationSync(address: string) {
        return false;
    }    

    async isResponsibleForSettlementSync(address: string) {
        let respSettlement = await this.rbbTokenSmartContract.responsibleForSettlement();
        console.log("respSettlement=" + respSettlement);
        console.log("isResponsibleForSettlementSync=");
        return respSettlement == address;
    }

    async isResponsibleForDisbursementSync() {
        return false;
    }       
//novas Funçoes

    async isClient (idclient: number, idFinancialSupportAgreement: string) {
    return await this.esgBndesTokenSmartContract.clients(idclient,idFinancialSupportAgreement);
    }
    async isSupplier (idsupplier: number) {
        return await this.esgBndesTokenSmartContract.suppliers(idsupplier);

    }
    async isInvestor (id: number){
        return await this.esgBndesTokenSmartContract.investors(id);
    }
    async isOperacional (id: number){
        return await this.rbbRegistrySmartContract.isRegistryOperational(id);
    }

   


    async isResposibleForPayingBNDESSuppliers(){
        
       let bndesResposible = await this.ESGBndesToken_BNDESRolesSmartContract.resposibleForPayingBNDESSuppliers();
       
       let contaBlockchain = await this.accountProvider.getSigner().getAddress();
       
         if (bndesResposible == contaBlockchain){
            return true;

        }
        else{
            return false;
        }

    }
    async isResponsibleForInitialAllocation(){
       let bndesResposible = await this.ESGBndesToken_BNDESRolesSmartContract.responsibleForInitialAllocation();
       let contaBlockchain = await this.accountProvider.getSigner().getAddress();
         if (bndesResposible == contaBlockchain){
            return true;

        }
        else{
            return false;
        }

    }

    async isResponsibleForDisbursement(){
        console.log("///////////////////////////////////////////////////////////////////");
        let bndesResposible = await this.ESGBndesToken_BNDESRolesSmartContract.responsibleForDisbursement();
        console.log(bndesResposible);
        let contaBlockchain = await this.accountProvider.getSigner().getAddress();
        console.log(contaBlockchain);
        console.log("///////////////////////////////////////////////////////////////////");
          if (bndesResposible == contaBlockchain){
             return true;
 
         }
         else{
             return false;
         }
 
     }
     async isResponsibleForInvestmentConfirmation(){
        let contaBlockchain = await this.accountProvider.getSigner().getAddress();
        let bndesResposible = await this.rbbTokenSmartContract.responsibleForInvestmentConfirmation();
        if (bndesResposible == contaBlockchain){
            return true;

        }
        else{
            return false;
        }
     }

     async isResponsibleForSettlement(){
        let contaBlockchain = await this.accountProvider.getSigner().getAddress();
        let bndesResposible = await this.rbbTokenSmartContract.responsibleForSettlement();
        if (bndesResposible == contaBlockchain){
            return true;

        }
        else{
            return false;
        }
     }





}
