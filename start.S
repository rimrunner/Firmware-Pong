.section ".text.boot"

.global _start   //start globaaliksi, että kaikki näkee tämän

_start:
/*
	//read cpu id, stop slave cores
	//Kolme seuraavaa käskyä: jos mpidr_el1 -rekisterissä kaksi ensimmäistä bittiä on nollia, branchataan labeliin 2f
	//Jos ne bitit ei ole nollia, silloin cpu id on suurempi kuin 0 ja lopetetaan
	mrs     x1, mpidr_el1  //mrs = move register to status eli siirtää mpidr_el1:n x1:een.
	//mpidr_el 1 on ilmeisesti assembleriin sisäänrakennettu kenttä, multiprocessor affinity [sukulaisuus] register.
	
	and     x1, x1, #3  //ruutu on immediate syntaksi, joka speisfioi välittömät data-arvot dataoperaatioille
	//kohderekisteri on sama kuin toinen operandi.
	//...000011 ANDataan eli jos siis viimeiset bitit ovat 1, ne ovat tuloksessakin päällä
	//mpidr_el1:en 7 ensimmäistä bittiä ovat affinity level 0. Ne määräävät PE:tä
	
	cbz     x1, 2f //cbz = compare and branch on zero; operaattorin rekisteri, label
1:
	wfe
	b       1b
2:  // Tänne mennään jos cpu id on 0
*/
	// Aluksi asetetaan stack pointeriin _start -labelin muistiosoite (stack ilmeisesti kasvaa eri suuntaan eli alas, niin se ei mene _start -käskyjen päälle)
	ldr     x7, =_start  //Lataa wordin (kahdeksan tavua ARMv8:ssa) rekisteriin x1, = -merkki spesifioi välittömän datan. Siihen tulee varmaan labelista sen muistiosoite (??). Pseudokäsky, jossa siis ilmeisesti lopulta tulee suoraan se _startin osoite tuohon.
	mov     sp, x7

	// clear bss
	ldr     x7, =__bss_start  //kuten ldr -käsky yllä
	ldr     x4, =__bss_size  //koko tulee kaiketi tavuina
loopbeg:
	cbz     x4, loopend  //Jos w2 on nolla eli bss on käyty läpi, hypätään 4:ään
	str     xzr, [x1], #8  //kopioidaan xzr:stä (zerotus-rekisteristä) 8 tavua x1:n arvoon osoitteena (hakasulut = käytetään rekisterin arvoa osoitteena) eli kirjoitetaan nollia __bss:ään. HUOM, #8 on tässä post-increment operandi, joka muuttaa ilmeisesti tuota x1:stä, että se kirjoittaa joka iteraatiolla eri kohtaan
	sub     x4, x4, #1 //Vähennetään 1 (tavu), koska käydään läpi tuota
	cbnz    x2, loopbeg  //cbnz = jos ei ole nolla, branchaa takaisin zerottamaan

loopend:	
	bl      main
	// for failsafe, halt this core too
//	b       1b
