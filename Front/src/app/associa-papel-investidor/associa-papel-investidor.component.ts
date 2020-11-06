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
  maskCnpj            : any;

  cnpj: string;
  cnpjWithMask: string;  


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
      }
  }

  async associaPapel() {

    let self = this;
    this.cnpj = Utils.removeSpecialCharacters(this.cnpjWithMask);


    console.log("conta selecionada na associacao do papel="  + this.selectedAccount);
    
    let b = await this.web3Service.isResponsavelPorAssociarInvestidorSync(this.selectedAccount);    
    if (!b) 
    {
      let s = "Conta selecionada no Metamask não pode executar a Confirmação.";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
    } 



    //TODO
  }  


}
