namespace Cepaf.Cockpit.Tests.BDD

open System
open TickSpec
open NUnit.Framework
open Cepaf.Cockpit.Scaffolder

// Run 2: Step Definitions - Scaffolder

type ScaffolderSteps() =
    
    // Mock State
    let wizard = ScaffolderWizardViewModel()
    
    [<Given>]
    member this.``the following templates exist:`` (table: Table) =
        // Populate Template List
        ()

    [<When>]
    member this.``I click on "(.*)"`` (templateName: string) =
        // Trigger selection
        ()

    [<Then>]
    member this.``I should see the "(.*)" screen`` (screen: string) =
        // Verify router
        ()

    [<Then>]
    member this.``the current step should be "(.*)"`` (step: int) =
        Assert.AreEqual(step, wizard.CurrentStep)

    [<When>]
    member this.``I click "Create"`` () =
        wizard.Execute()

    [<Then>]
    member this.``I should see "(.*)" in the logs`` (text: string) =
        // Verify log stream
        ()
