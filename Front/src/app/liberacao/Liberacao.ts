export class Liberacao {
  rbbId: number;
  contaBlockchainBNDES: string;
  cnpj: string;
  cnpjWithMask: string;  
  subcreditos: Subcredito[];
  numeroSubcreditoSelecionado: number;
  razaoSocial: string;
  valor: number;
  saldoCNPJ: number;
  saldoBNDESToken: number;
  hashID: string;
}

export class Subcredito {
  numero: number;
}