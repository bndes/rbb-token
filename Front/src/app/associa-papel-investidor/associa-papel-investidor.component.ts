import { Component, OnInit, NgZone, ChangeDetectorRef } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';
import { BnAlertsService } from 'bndes-ux4';
import { DeclarationComponentInterface } from '../shared/declaration-component.interface';

import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { Web3Service } from './../Web3Service';
import { Utils } from '../shared/utils';

@Component({
  selector: 'app-associa-papel-investidor',
  templateUrl: './associa-papel-investidor.component.html',
  styleUrls: ['./associa-papel-investidor.component.css']
})
export class AssociaPapelInvestidorComponent implements OnInit {

  selectedAccount: any;
  maskCnpj : any;

  cnpj: string;
  cnpjWithMask: string;  
  razaoSocial: string;


  constructor(private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService,
    private web3Service: Web3Service, private router: Router, private zone: NgZone, private ref: ChangeDetectorRef) { 

    let self = this;
    setInterval(function () {
      self.recuperaContaSelecionada(), 
      1000});

  }

  ngOnInit() {
    this.maskCnpj = Utils.getMaskCnpj(); 

  }

  async recuperaContaSelecionada() {
            
    let self = this;    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {

      this.selectedAccount = newSelectedAccount;
          console.log("selectedAccount=" + this.selectedAccount);
          //this.verificaEstadoContaBlockchainSelecionada(this.selectedAccount);

      let ResponsavelPorAssociarInvestidor = await this.web3Service.isResponsavelPorAssociarInvestidorSync();
      if (!ResponsavelPorAssociarInvestidor) 
        {
          let s = "Conta selecionada no Metamask não pode executar a Confirmação.";
          this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
          
        } 
      }
  }

  recuperaInformacoesDerivadasCNPJ() {
    this.cnpj = Utils.removeSpecialCharacters(this.cnpjWithMask);

    if ( this.cnpj.length == 14 ) { 
      console.log (" Buscando o CNPJ do cliente (14 digitos fornecidos)...  ")
      this.recuperaClientePorCNPJ(this.cnpj);
    } 
    else {
      this.razaoSocial="";
    }

  }

  recuperaClientePorCNPJ(cnpj) {
    console.log(cnpj);

    this.pessoaJuridicaService.recuperaEmpresaPorCnpj(cnpj).subscribe(
      empresa => {
        if (empresa && empresa.dadosCadastrais) {
          console.log("empresa encontrada abaixo ");
          console.log(empresa);

          this.razaoSocial = empresa.dadosCadastrais.razaoSocial;
        }
        else {
          let texto = "Nenhuma empresa encontrada com o cnpj " + cnpj;
          console.log(texto);
          Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);

        }
      },
      error => {
        let texto = "Erro ao buscar dados da empresa";
        console.log(texto);
        Utils.criarAlertaErro( this.bnAlertsService, texto,error);
      });

  }  


  async associaPapel() {

    let self = this;
    this.cnpj = Utils.removeSpecialCharacters(this.cnpjWithMask);

     

    let idInvestor = (await this.web3Service.getRBBIDByCNPJSync(parseInt(this.cnpj)));
    let isInvestor = await this.web3Service.isInvestor(idInvestor);
    if (isInvestor) 
    {
        let s = "esse CNPJ ja é um Investidor";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
    }
    //Todo criar conta especifica para cadastro de investidor 
    
    let ResponsavelPorAssociarInvestidor = await this.web3Service.isResponsavelPorAssociarInvestidorSync();
    if (!ResponsavelPorAssociarInvestidor) 
    {
        let s = "Conta selecionada no Metamask não pode executar a Confirmação.";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
    } 

    let rbbID = <number> (await this.web3Service.getRBBIDByCNPJSync(parseInt(this.cnpj)));

    if (!rbbID) {
      let s = "CNPJ não está cadastrado.";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    } 
    
    this.web3Service.associaInvestidor(rbbID).then(
      
      function(txHash) { 

        Utils.criarAlertasAvisoConfirmacao( txHash, 
          self.web3Service, 
          self.bnAlertsService, 
          "O solicitação de associação do cnpj " + self.cnpj + " como papel de investidor foi enviada. Aguarde a confirmação.", 
          "A associação foi confirmada na blockchain.", 
          self.zone) 

          //TODO: url para investidor
        self.router.navigate(['sociedade/dash-papeis']);

      },
      function(error) {  
        Utils.criarAlertaErro( self.bnAlertsService, 
          "Erro ao associar investidor na blockchain", 
          error);  
      });    

      Utils.criarAlertaAcaoUsuario( self.bnAlertsService, 
                                "Confirme a operação no metamask e aguarde a confirmação da associação da conta.")

  }  


}
