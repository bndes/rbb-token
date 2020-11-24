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
    private accountProvider: any;

    private addrContratoRBBToken: string = '';
    private addrContratoESGBndesToken: string = '';
    private addrContratoESGBndesToken_GetDataToCall: string = '';
    private addrContratoRBBRegistry: string = '';

    private abiRBBToken: string = '';
    private abiESGBndesToken: string = '';
    private abiESGBndesToken_GetDataToCall: string = ''; 
    private abiRBBRegistry: string = '';

    private rbbTokenSmartContract: any;
    private esgBndesTokenSmartContract: any;
    private esgBndesToken_GetDataToCallSmartContract: any;
    private rbbRegistrySmartContract: any;


    private blockchainNetwork: string = '';

    private vetorTxJaProcessadas : any[];

    private eventoRBBToken: any;
    private eventoTokenEspecifico: any;

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
        console.log("Web3Service.ts :: Selecionou URL = " + this.serverUrl)

        this.http.post<Object>(this.serverUrl + 'constantesFront', {}).subscribe(
            data => {

                this.blockchainNetwork = data["blockchainNetwork"];
    
                this.addrContratoRBBToken = data["addrContratoRBBToken"];
                this.addrContratoESGBndesToken = data["addrContratoESGBndesToken"];
                this.addrContratoESGBndesToken_GetDataToCall = data["addrContratoESGBndesToken_GetDataToCall"];
                this.addrContratoRBBRegistry = data["addrContratoRBBRegistry"];
    
                this.abiRBBToken = data['abiRBBToken'];
                this.abiESGBndesToken = data['abiESGBndesToken'];
                this.abiESGBndesToken_GetDataToCall = data['abiESGBndesToken_GetDataToCall']; 
                this.abiRBBRegistry = data['abiRBBRegistry'];
            

                this.intializeWeb3();
                this.inicializaQtdDecimais();

            },
            error => {
                console.log("**** Erro ao buscar constantes do front");
            });
            
    }

 
    intializeWeb3() {

        this.provider = new ethers.providers.JsonRpcProvider("http://35.239.231.134:4545/");
        this.ethereum =  window['ethereum'];
        console.log("provider ethers");
        console.log(this.provider);

        this.rbbTokenSmartContract = new ethers.Contract(this.addrContratoRBBToken, this.abiRBBToken, this.provider);
        this.esgBndesTokenSmartContract = new ethers.Contract(this.addrContratoESGBndesToken,this.abiESGBndesToken, this.provider);
        this.esgBndesToken_GetDataToCallSmartContract = new ethers.Contract(this.addrContratoESGBndesToken_GetDataToCall, this.abiESGBndesToken_GetDataToCall, this.provider);
        this.rbbRegistrySmartContract = new ethers.Contract(this.addrContratoRBBRegistry, this.abiRBBRegistry, this.provider);

        this.accountProvider = new ethers.providers.Web3Provider(this.ethereum);

        console.log("INICIALIZOU O WEB3 - rbbTokenSmartContract abaixo");
        console.log("accountProvider=");
        console.log(this.accountProvider);        

    } 


    getBlockTimestamp(blockHash: number, fResult: any) {

//        this.web3.eth.getBlock(blockHash, fResult);

    }


    public getInfoBlockchainNetwork(): any {

        let blockchainNetworkAsString = "Localhost";
        let blockchainNetworkPrefix = "";
        if (this.blockchainNetwork=="4") {
            blockchainNetworkAsString = "Rinkeby";
            blockchainNetworkPrefix = "rinkeby."
        }
        else if (this.blockchainNetwork=="1") {
            blockchainNetworkAsString = "Mainnet";
        }
        else if (this.blockchainNetwork=="648629") {
            blockchainNetworkAsString = "RBB";
            //TODO: FALTA DEFINIR CAMINHO PARA BLOCK EXPLORER DO RBB
        }

        return {
            blockchainNetwork:this.blockchainNetwork,
            blockchainNetworkAsString:blockchainNetworkAsString,
            blockchainNetworkPrefix: blockchainNetworkPrefix,

            addrContratoRBBToken: this.addrContratoRBBToken,
            addrContratoESGBndesToken: this.addrContratoESGBndesToken,
            addrContratoRBBRegistry: this.addrContratoRBBRegistry,
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
        let events = await this.esgBndesTokenSmartContract.queryFilter(filter);
        console.log("events recuperaEventosAdicionaInvestidor");    
        console.log(events); 

        //tste2
        let topic = ethers.utils.id("FA_InvestorAdded(uint id");
        filter = {
            address: this.addrContratoESGBndesToken,
            topics: [ topic ]
        };

        this.provider.on(filter, (result) => {
            console.log("dentro do evento do eethers do associa inv");
            console.log(result);
        });
       


    }


    //https://docs.ethers.io/v4/api-contract.html

    registraEventosAdicionaInvestidor(callback) {
 //       this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InvestorAdded({}, { fromBlock: 0, toBlock: 'latest' });
 //       this.eventoTokenEspecifico.watch(callback);
    }
    registraEventosAdicionaCliente(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_ClientAdded({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }    
    registraEventosAdicionaFornecedor(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_SupplierAdded({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }    

    registraEventosRegistrarInvestimento(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InvestmentBooked({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosRecebimentoInvestimento(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InvestmentConfirmed({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosAlocacaoParaDesembolso(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InitialAllocation_Disbursements({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosAlocacaoParaContaAdm(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InitialAllocation_Fee({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    async registraEventosLiberacao(callback) {

        let filter = this.esgBndesTokenSmartContract.filters.FA_Disbursement(null);
        let events = await this.esgBndesTokenSmartContract.queryFilter(filter);
        console.log("events registraEventosLiberacao");    
        console.log(events); 

        /*
        console.log("web3 - registraEventosLiberacao");

        let topic = ethers.utils.id("FA_Disbursement(uint idClient, string idFinancialSupportAgreement, uint amount, bytes32 docHash");
        let filter = {
            address: this.addrContratoESGBndesToken,
            topics: [ topic ]
        };

//        this.provider.on(filter,callback); 
        this.provider.on(filter, (result) => {
            console.log("dentro do evento do eethers");
            console.log(result);
        });
        */
        

    }

    registraEventosPagamentoFornecedores(callback) {

//        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_TokenTransfer({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosBNDESPagaFornecedores(callback) {
//        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_BNDES_TokenTransfer({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoTokenEspecifico.watch(callback);
    }    
    
    registraEventosResgate(callback) {
//        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_RedemptionRequested({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosLiquidacaoResgate(callback) {
//        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_RedemptionSettlement({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoTokenEspecifico.watch(callback);
    }

 //TODO: alterar esses eventos para dashboard de intervencoes manuais. Falta incluir ESG_BndesToken_BndesRoles 
    registraEventosIntervencaoManualMintBurn(callback) {
        console.log("web3-registraEventosIntervencaoManual");        
//        this.eventoDoacao = this.bndesTokenSmartContract.ManualIntervention_MintAndBurn({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoDoacao.watch(callback);
    }
    registraEventosIntervencaoManualFee(callback) {
        console.log("web3-registraEventosIntervencaoManualFee");        
//        this.eventoDoacao = this.bndesTokenSmartContract.ManualIntervention_Fee({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoDoacao.watch(callback);
    }
    registraEventosIntervencaoManualRoleOrAddress(callback) {
        console.log("web3-registraEventosIntervencaoManual-RoleOrAddress");        
//        this.eventoDoacao = this.bndesRegistrySmartContract.ManualIntervention_RoleOrAddress({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoDoacao.watch(callback);
    }

    

    registraWatcherEventosLocal(txHashProcurado, callback) {
        
        let self = this;
        console.info("Callback ", callback);
        const filtro = { fromBlock: 'latest', toBlock: 'pending' }; 
/* TODO        
        this.eventoRBBToken = this.rbbTokenSmartContract.allEvents( filtro );                 
        this.eventoRBBToken.watch( function (error, result) {
            console.log("Watcher Token Genérico executando...")
            self.procuraTransacao(error, result, txHashProcurado, self, callback);
        });
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.allEvents( filtro );                 
        this.eventoTokenEspecifico.watch( function (error, result) {
            console.log("Watcher Token Específico executando...")
            self.procuraTransacao(error, result, txHashProcurado, self, callback);
        });
*/
        console.log("registrou o watcher de eventos");
        
    }

    procuraTransacao(error, result, txHashProcurado, self, callback) {
        console.log( "Entrou no procuraTransacao" );
        console.log( "txHashProcurado: " + txHashProcurado );
        console.log( "result.transactionHash: " + result.transactionHash );
        self.web3.eth.getTransactionReceipt(txHashProcurado,  function (error, result) {
            if ( !error ) {
                let status = result.status
                let STATUS_MINED = 0x1
                console.log("Achou o recibo da transacao... " + status)     
                if ( status == STATUS_MINED && !self.vetorTxJaProcessadas.includes(txHashProcurado)) {
                    self.vetorTxJaProcessadas.push(txHashProcurado);
                    callback(error, result);        
                } else {
                    console.log('"Status da tx pendente ou jah processado"')
                }
            }
            else {
              console.log('Nao eh o evento de confirmacao procurado')
            } 
        });     
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

    ////////////////////// FIM REGISTRY

    ////////////////////// INICIO INVESTIDOR


    async associaInvestidor(rbbID: number): Promise<any> {

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.esgBndesTokenSmartContract.connect(signer);
        return (await contWithSigner.addInvestor(rbbID));
    }

    async registrarInvestimento(amount: number): Promise<any> {
        
        console.log("Registra doacao!!! ");
        
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

        let retornedValue = await this.rbbTokenSmartContract.balanceRequestedTokens(this.ID_SPECIFIC_TOKEN,specificHash);

        return self.converteInteiroParaDecimal( retornedValue.toNumber() );
    }


    async receberDoacao(rbbIDInvestor: number, amount: number, docHash: string): Promise<any> {
        
        console.log("***** Web3Service - ReceberDoacao 2");
        amount = this.converteDecimalParaInteiro(amount); 
        console.log("amount=" + amount);
        console.log("inv=" + rbbIDInvestor);
        console.log("addr=" + this.addrContratoESGBndesToken);

        //TODO: resolver o que fazer porque não temos um saldo de investidor isolado
        let specificHash = <string> (await this.getSpecificHashAsUint(30));

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);

        //TODO: Trocar fake hash pelo hash
        return (await contWithSigner.mint(this.addrContratoESGBndesToken, rbbIDInvestor, specificHash, 
            amount, this.FAKE_HASH, []));  
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
            let valorToHash = this.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER;
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

    async resgata(transferAmount: number) {

        console.log("Web3Service - Redeem");

        let callData = await this.esgBndesToken_GetDataToCallSmartContract.getRedeemData();
        console.log(callData);
        let fromHash = callData[0];
        console.log(fromHash);

        let dataFromDD = callData[1];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);     

        console.log('TransferAmount(after)=' + transferAmount);

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

        
        return (await contWithSigner.redeem (
                this.addrContratoESGBndesToken, hashResgate, this.FAKE_HASH, emptyData));
     
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

    isResponsibleForSettlementSync(address: string) {
        return false;
    }

    async isResponsibleForDisbursementSync() {
        return false;
    }       
}