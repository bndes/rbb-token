import { Component, OnInit, NgZone } from '@angular/core'
import { ChangeDetectorRef } from '@angular/core'
import { Router, ActivatedRoute, ParamMap } from '@angular/router';
import { FileHandleService } from '../file-handle.service';
import { Web3Service } from './../Web3Service'
import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { DeclarationComponentInterface } from '../shared/declaration-component.interface';
import { BnAlertsService } from 'bndes-ux4'
import { LiquidacaoResgate } from './liquidacao-resgate';
import { ConstantesService } from '../ConstantesService';
import { Utils } from '../shared/utils';

@Component({
  selector: 'app-liquidacao-resgate',
  templateUrl: './liquidacao-resgate.component.html',
  styleUrls: ['./liquidacao-resgate.component.css']
})
export class LiquidacaoResgateComponent implements OnInit, DeclarationComponentInterface {

  liquidacaoResgate: LiquidacaoResgate;

  selectedAccount: any;

  solicitacaoResgateId: string;
  maskCnpj: any;  
  URLBlockchainExplorer: string;  
  hashdeclaracao      : string;
  flagUploadConcluido : boolean;

  constructor(private pessoaJuridicaService: PessoaJuridicaService,
    private fileHandleService: FileHandleService,    
    private bnAlertsService: BnAlertsService,
    private web3Service: Web3Service,
    private ref: ChangeDetectorRef,
    private zone: NgZone, private router: Router, private route: ActivatedRoute ) { }

  ngOnInit() {

    this.maskCnpj = Utils.getMaskCnpj();      

    let self = this;
    setInterval(function () {
      self.recuperaContaSelecionada(), 1000});  
      
    this.liquidacaoResgate = new LiquidacaoResgate();
    this.liquidacaoResgate.hashResgate = this.route.snapshot.paramMap.get('solicitacaoResgateId');

    console.log("this.liquidacaoResgate.hashResgate=");
    console.log(this.liquidacaoResgate.hashResgate);

    self.recuperaStatusResgate();
    self.recuperaStatusLiquidacaoResgate();    
    
    this.flagUploadConcluido = false;     
    this.hashdeclaracao = "";   

  }


  async recuperaContaSelecionada() {
            
    let self = this;    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
        if ( this.flagUploadConcluido == false ) {
          this.selectedAccount = newSelectedAccount;
          console.log("selectedAccount=" + this.selectedAccount);          
          //this.preparaUpload(self.liquidacaoResgate.cnpj, this.selectedAccount, this);
          this.fileHandleService.atualizaUploaderComponent(self.liquidacaoResgate.cnpj, 0, this.selectedAccount, "comp_liq", this);
          this.atualizaIsResponsibleForSettlement();
        }
        else {
          console.log( "Upload has already made! You should not change your account. Reseting... " );
          this.cancelar();
        }
    }
    
  }

  preparaUpload(cnpj, selectedAccount, self) {

    const tipo = "comp_liq";

    if (cnpj &&  selectedAccount) {
      this.fileHandleService.atualizaUploaderComponent(cnpj, 0, selectedAccount, tipo, self);
    }
  }

  cancelar() { 
    this.liquidacaoResgate = new LiquidacaoResgate();    
    this.flagUploadConcluido = false;     
  }

  recuperaStatusResgate() {

    let self = this;

    this.web3Service.recuperaEventosResgateByHash(self.liquidacaoResgate.hashResgate).then(function(evento) {
      
      if (evento) {

        self.liquidacaoResgate.rbbId = evento.idClaimer;
//TODO?????????
        self.liquidacaoResgate.cnpj = "FALTA_BUSCAR";//Utils.completarCnpjComZero(evento.args.cnpj);
        self.liquidacaoResgate.valorResgate = self.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount));
        self.preparaUpload(self.liquidacaoResgate.cnpj, self.selectedAccount, self);
        self.recuperaDataHora(evento).then(function(dataHora) {
          self.liquidacaoResgate.dataHoraResgate = dataHora;
          self.ref.detectChanges();
        }) 
       }
       else {
         console.log("ERRO - evento de resgate não encontrado");
       }
    });
    
  }

  
  async recuperaStatusLiquidacaoResgate() {
    let self = this;
    this.URLBlockchainExplorer = this.web3Service.getInfoBlockchain().URLBlockchainExplorer; 
    
    let eventos = await this.web3Service.recuperaEventosLiquidacaoResgate();

    console.log("eventos liq resg");

    for (let i=0; i< eventos.length; i++)  {
      let evento = eventos[i];
      console.log(evento);
      if (evento.args.redemptionTransactionHash == self.liquidacaoResgate.hashResgate) {

            self.liquidacaoResgate.hashID       = evento.transactionHash;
            self.liquidacaoResgate.hashComprovacao = evento.args.docHash;
            self.liquidacaoResgate.isLiquidado = true;
            self.recuperaDataHora(evento).then(function(dataHora) {
              self.liquidacaoResgate.dataHoraLiquidacao = dataHora;
              self.ref.detectChanges();
            }) 
    
            self.recuperaFilePathAndName(self,self.liquidacaoResgate);
      }
      
    };

  }

  async atualizaIsResponsibleForSettlement() {

    this.liquidacaoResgate.isSelectedAccountResponsibleForSettlement = false;    
    let bRS = await this.web3Service.isResponsibleForSettlementSync(this.selectedAccount);
    if(bRS) {
      this.liquidacaoResgate.isSelectedAccountResponsibleForSettlement = true;
    }
  }

  recuperaFilePathAndName(self,transacao) {

    
    if ( transacao == undefined ||  (transacao.cnpj == undefined || transacao.cnpj == "" ) || ( transacao.hashComprovacao == undefined || transacao.hashComprovacao == "") 
        || transacao.contratoFinanceiro == undefined ) {
      console.log("Transacao incompleta no recuperaFilePathAndName do dashboard-resgate");
      return;
    }

    self.fileHandleService.buscaFileInfo(transacao.cnpj, 0, "0", transacao.hashComprovacao, "comp_liq").subscribe(
        result => {
          if (result && result.pathAndName) {
            transacao.filePathAndName=ConstantesService.serverUrlRoot+result.pathAndName;
          }
          else {
            let texto = "Não foi possível encontrar informações associadas ao arquivo.";
            console.log(texto);
            Utils.criarAlertaAcaoUsuario( self.bnAlertsService, texto);       
          }                  
        }, 
        error => {
          let texto = "Erro ao buscar dados de arquivo";
          console.log(texto);
          console.log("cnpj=" + transacao.cnpj);
          console.log("contratoFinanceiro=" + transacao.contratoFinanceiro);          
          console.log("hashComprovacao=" + transacao.hashComprovacao);
//              Utils.criarAlertaErro( self.bnAlertsService, texto,error);
        }) //fecha busca fileInfo

}


  async liquidar() {
    this.liquidacaoResgate.hashComprovacao = this.hashdeclaracao ;
    console.log("Liquidando o resgate..");
    console.log("hashResgate" + this.liquidacaoResgate.hashResgate);
    console.log("hashComprovacao" + this.liquidacaoResgate.hashComprovacao);    


    let bRS = await this.web3Service.isResponsibleForSettlementSync(this.selectedAccount);
    if (!bRS) {
      let s = "Conta não é do responsável pela liquidação";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }

    if (this.liquidacaoResgate.hashComprovacao==undefined || this.liquidacaoResgate.hashComprovacao==null) {
      let s = "O hash da comprovação é um Campo Obrigatório";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 2);
      return;
    }
    else if (!Utils.isValidHash(this.liquidacaoResgate.hashComprovacao)) {
      let s = "O Hash do comprovante está preenchido com valor inválido";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 2)
      return;
    }


    let self= this;


    this.web3Service.liquidaResgate(this.liquidacaoResgate.hashResgate, this.liquidacaoResgate.hashComprovacao).then(
      
      function(txHash) { 
 
        Utils.criarAlertasAvisoConfirmacao( txHash, 
                                            self.web3Service, 
                                            self.bnAlertsService, 
                                            "Liquidação do resgate foi enviada. Aguarde a confirmação.", 
                                            "Liquidação do resgate foi confirmada na blockchain.", 
                                            self.zone)    
            self.router.navigate(['sociedade/dash-transf']);          
        },
       function(error) {  
        Utils.criarAlertaErro( self.bnAlertsService, 
                               "Erro ao liquidar resgate.", 
                               error )  
       });
       Utils.criarAlertaAcaoUsuario( self.bnAlertsService, 
                                   "Confirme a operação no metamask e aguarde a liquidação da conta." )

  }
  

  async recuperaDataHora(event) {

    let timestamp = await this.web3Service.getBlockTimestamp(event.blockNumber);
    return new Date(timestamp * 1000);
}


}
