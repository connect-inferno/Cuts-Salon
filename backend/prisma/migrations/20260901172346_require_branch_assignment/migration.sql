/*
  Warnings:

  - Made the column `branchId` on table `Bill` required. This step will fail if there are existing NULL values in that column.
  - Made the column `branchId` on table `Customer` required. This step will fail if there are existing NULL values in that column.
  - Made the column `branchId` on table `EmployeeProfile` required. This step will fail if there are existing NULL values in that column.

*/
-- DropForeignKey
ALTER TABLE "Bill" DROP CONSTRAINT "Bill_branchId_fkey";

-- DropForeignKey
ALTER TABLE "Customer" DROP CONSTRAINT "Customer_branchId_fkey";

-- DropForeignKey
ALTER TABLE "EmployeeProfile" DROP CONSTRAINT "EmployeeProfile_branchId_fkey";

-- AlterTable
ALTER TABLE "Bill" ALTER COLUMN "branchId" SET NOT NULL;

-- AlterTable
ALTER TABLE "Customer" ALTER COLUMN "branchId" SET NOT NULL;

-- AlterTable
ALTER TABLE "EmployeeProfile" ALTER COLUMN "branchId" SET NOT NULL;

-- AddForeignKey
ALTER TABLE "EmployeeProfile" ADD CONSTRAINT "EmployeeProfile_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Customer" ADD CONSTRAINT "Customer_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Bill" ADD CONSTRAINT "Bill_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
