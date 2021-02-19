import { Component, OnInit, NgZone, ChangeDetectorRef } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';
import { BnAlertsService } from 'bndes-ux4';
import { FileHandleService } from '../file-handle.service';
import { DeclarationComponentInterface } from '../shared/declaration-component.interface';

import { Doacao } from "./Doacao";
import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { Web3Service } from './../Web3Service';
import { Utils } from '../shared/utils';

import {PessoaJuridicaHandle} from '../PessoaJuridicaHandle/PessoaJuridicaHandle';


@Component({
  selector: 'app-confirma-doacao',
  templateUrl: './confirma-doacao.component.html',
  styleUrls: ['./confirma-doacao.component.css']
})
export class ConfirmaDoacaoComponent implements OnInit, DeclarationComponentInterface {

  doacao: Doacao = new Doacao();

  selectedAccount: any;

  maskCnpj            : any;
  hashdeclaracao      : string;
  flagUploadConcluido : boolean;

  CONTRATO_DOADOR = 0;  

  constructor(private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService,
    private web3Service: Web3Service, private router: Router, private zone: NgZone, private ref: ChangeDetectorRef,
    private fileHandleService: FileHandleService,private pessoaJuridicaHandle:PessoaJuridicaHandle) {       

      let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 
        1000});
    }

  ngOnInit() {
    this.maskCnpj = Utils.getMaskCnpj(); 
    this.doacao = new Doacao();
    this.pessoaJuridicaHandle.razaoSocial="";
    this.pessoaJuridicaHandle.cnpj="";

  }

  inicializaDoacao() {
    //this.doacao.dadosCadastrais = undefined;
    //this.doacao.cnpj = "";
    this.doacao.saldo = undefined;
    this.doacao.valor = 0;
    this.hashdeclaracao = "";   
    this.flagUploadConcluido = false;     
  }

    async recuperaContaSelecionada() {
            
    let self = this;    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
        if ( this.flagUploadConcluido == false ) {
          this.selectedAccount = newSelectedAccount;
          console.log("selectedAccount=" + this.selectedAccount);

          if (!(await this.web3Service.isResponsibleForInvestmentConfirmation())) {
            let s = "essa conta nao é responsavel por confirmação";
            this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
          }

          //this.verificaEstadoContaBlockchainSelecionada(this.selectedAccount);
          this.preparaUpload(this.pessoaJuridicaHandle.cnpj, this.selectedAccount, this);
        }
        else {
          console.log( "Upload has already made! You should not change your account. Reseting... " );
          this.cancelar();
        }
    }
    
  }

  preparaUpload(cnpj, selectedAccount, self) {

    const tipo = "comp_doacao";

    if (cnpj &&  selectedAccount) {
      this.fileHandleService.atualizaUploaderComponent(cnpj, this.CONTRATO_DOADOR, selectedAccount, tipo, self);
    }
  }

    changeCnpj() {

      this.pessoaJuridicaHandle.cnpj = Utils.removeSpecialCharacters(this.doacao.cnpjWithMask);
      let cnpj = this.pessoaJuridicaHandle.cnpj;
  
      if ( cnpj.length == 14 ) { 
        console.log (" Buscando o CNPJ  (14 digitos fornecidos)...  " + cnpj)
        this.pessoaJuridicaHandle.recuperaClientePorCNPJ();
        this.recuperaSaldo(this.pessoaJuridicaHandle.cnpj);
      } 
    else{
      this.pessoaJuridicaHandle.razaoSocial = "";
    } 

      this.fileHandleService.atualizaUploaderComponent(this.pessoaJuridicaHandle.cnpj, this.CONTRATO_DOADOR, this.selectedAccount, "comp_doacao", this);
    }
  
    cancelar() { 
      this.doacao = new Doacao();
      this.inicializaDoacao();
    }
    /*
    recuperaDoadorPorCNPJ(cnpj) {
      console.log("RECUPERA Doador com CNPJ =" + cnpj)
  
      this.pessoaJuridicaService.recuperaEmpresaPorCnpj(cnpj).subscribe(
        empresa => {
          if (empresa && empresa.dadosCadastrais.razaoSocial) {
            console.log("empresa encontrada - ")
            console.log(empresa)
  
            this.doacao.dadosCadastrais = empresa["dadosCadastrais"];
            this.recuperaSaldo(cnpj);
  
          }
          else {
            let texto = "CNPJ não identificado";
            console.log(texto);
            Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);
          }
        },
        error => {
          let texto = "Erro ao buscar dados da empresa";
          console.log(texto);
          Utils.criarAlertaErro( this.bnAlertsService, texto,error);
        })
    }
    */

    async recuperaSaldo(cnpj) {

      this.doacao.rbbId = <number> (await this.web3Service.getRBBIDByCNPJSync (cnpj));
      
      this.doacao.saldo = <number> (await this.web3Service.getBalanceRequestedToken(this.doacao.rbbId));
  
    }

    async receberDoacao() {

      let self = this;
/*
//TODO: verificar se eh quem pode confirmar
      let bRD = await this.web3Service.isResponsibleForDonationConfirmationSync(this.selectedAccount);    
      if (!bRD) 
      {
        let s = "Conta selecionada no Metamask não pode executar a Confirmação.";
          this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
          return;
      } 
*/
/*
//TODO: verificar se é um doador
      if (!contaBlockchainDoador) {
        let s = "CNPJ não é de um doador";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
      }
 */ 
      if (!(await this.web3Service.isResponsibleForInvestmentConfirmation())) {
        let s = "essa conta nao é responsavel por confirmação";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
      }   
     
      if (!this.doacao.rbbId) {
        let s = "CNPJ do investidor não está cadastrado.";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
      } 

      if (this.hashdeclaracao==undefined || this.hashdeclaracao==null || this.hashdeclaracao == "") {
        let s = "O envio da declaração é obrigatório";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 2)
        return
      } 
      
      else if (!Utils.isValidHash(this.hashdeclaracao)) {
        let s = "O Hash do comprovante está preenchido com valor inválido";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 2)
        return;
      }
        
      //Multipliquei por 1 para a comparacao ser do valor (e nao da string)
      if ((this.doacao.valor * 1) > (this.doacao.saldo * 1)) {
  
        console.log("saldo=" + this.doacao.saldo);
        console.log("valor=" + this.doacao.valor);
  
        let s = "Não é possível receber um investimento maior do que o valor do saldo do doador.";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
      }
  
  
      this.web3Service.receberDoacao(this.doacao.rbbId, this.doacao.valor, this.hashdeclaracao).then(
      
        function(txHash) {  
          Utils.criarAlertasAvisoConfirmacao( txHash, 
            self.web3Service, 
            self.bnAlertsService, 
            "O recebimento do investimento vindo do CNPJ " + self.pessoaJuridicaHandle.cnpj + "  foi enviado. Aguarde a confirmação.", 
            "O recebimento do investimento foi confirmado na blockchain.", 
            self.zone);       
            self.router.navigate(['sociedade/dash-doacao']);

        },
        function(error) {  
          Utils.criarAlertaErro( self.bnAlertsService, 
            "Erro ao receber investimento na blockchain", 
            error);  
        });    
  
      Utils.criarAlertaAcaoUsuario( self.bnAlertsService, 
                                    "Confirme a operação no metamask e aguarde a confirmação do recebimento do investimento." )  
      }
  
  
  
  }

  

