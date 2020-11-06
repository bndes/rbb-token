import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { AssociaPapelInvestidorComponent } from './associa-papel-investidor.component';

describe('AssociaPapelInvestidorComponent', () => {
  let component: AssociaPapelInvestidorComponent;
  let fixture: ComponentFixture<AssociaPapelInvestidorComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ AssociaPapelInvestidorComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(AssociaPapelInvestidorComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
